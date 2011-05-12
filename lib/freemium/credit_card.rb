require 'active_merchant/billing/expiry_date'

# stores the credit card information locally (card type, expiration, display number, zip_code)
module Freemium
  module CreditCard
    DB_FIELDS=[:zip_code, :address1, :address2, :city, :state, :card_type, :name]

    VIRTUAL_FIELDS=[
      # Essential attributes for a valid, non-bogus creditcards
      :number, :month, :year,      
#      :name, :first_name, :last_name,
      # Required for Switch / Solo cards
      :start_month, :start_year, :issue_number,
      # Optional verification_value (CVV, CVV2 etc). Gateways will try their best to 
      # run validation on the passed in value if it is supplied
      :verification_value
      ]
      #fields we want to store in remote system
      REMOTE_FIELDS=DB_FIELDS+VIRTUAL_FIELDS
      
    def self.included(base)
      base.class_eval do
        include ActiveMerchant::Billing::CreditCardMethods
        include ActiveMerchant::Billing::CreditCardFormatting
        include ActiveMerchant::Billing::CreditCardValidations

        attr_accessor :storage_failure
        attr_accessor *VIRTUAL_FIELDS
        #set this if the values were stored using trustee
        attr_accessor :trustee

        attr_accessible *DB_FIELDS
        attr_accessible *VIRTUAL_FIELDS
        attr_accessible :expiration
        attr_accessible :trustee
                
        #has_one :subscription, :class_name => "FreemiumSubscription"
        
        validate          :no_storage_failure
        before_validation :sanitize_credit_card_data, :if => :changed?
        before_validation :set_table_data, :if => :changed?
        #TODO: :if => :changed?
        before_destroy    :cancel_in_remote_system
        before_save       :store_credit_card_offsite, :if => :should_store_offsite?
      end
    end

    public

    #clear out the status flags
    def reload
      (VIRTUAL_FIELDS).each { |f| self.send("#{f}=",nil)}
      @trustee=false
      super
    end

    def type
      card_type
    end
    
    # mwagner - We need to know whether to store the card, or if it's already stored
    #if it is stored in trustee, or there is a billing key and it hasn't been changed
    def stored_offsite?
      (@trustee == true || (! billing_key.blank? && !changed?))
    end

    def should_store_offsite?
      changed? && (@trustee != true)
    end

    ##
    ## From ActiveMerchant::Billing::CreditCard
    ##    

    # Provides proxy access to an expiry date object
    def expiry_date
      ActiveMerchant::Billing::CreditCard::ExpiryDate.new(month, year)
    end

    def expired?
      expiry_date.expired?
    end

    # mmyy
    def expiration=(value)
      self.month=value[0..1]
      self.year=value[2..3]
      # have expiry parse the thing
      self.year=expiry_date.expiration.year
    end

    # def name
    #   @name || "#{first_name} #{last_name}"
    # end

    def address
      unless @address
        @address = Address.new
        @address.zip = self.zip_code
      end
      @address
    end
    
    ##
    ## Overrides
    ##
    
    # We're overriding AR#changed? to include instance vars that aren't persisted to see if a new card is being set
    def changed?
      #card_type_changed?
      ret=(changed & DB_FIELDS).present? || VIRTUAL_FIELDS.any? {|attr| self.send(attr).present?}
      ret
    end

    def set_table_data
      self.display_number  = self.class.mask(number) unless number.blank?
      self.expiration_date = expiry_date.expiration
    end
    ##
    ## Validation
    ##
    
    def validate
      # We don't need to run validations unless it's a new record or the
      # record has changed
      return unless new_record? || changed?

      #to store offsite, we need the complete card details
      if should_store_offsite?
        validate_credit_card_data
      else
        # We have a billing key - so just do our basic validation
        validate_basics
      end
    end

    def validate_basics
      errors.add :month,      "is not a valid month" unless valid_month?(self.month)
      errors.add :year,       "expired"              if expired?
      #TODO: do we need to verify the year is valid?
      errors.add :year,       "is not a valid year"  unless valid_expiry_year?(self.year)
      #NOTE: this may be covered by no_storage_failure check
      errors.add :number,     "not stored offsite"   if billing_key.blank?
      # TODO - Validate the billing_key length or something, too
    end

    def no_storage_failure
      errors.add @storage_failure,     "Missing Field" if (@storage_failure && @storage_failure != false)
    end

    # it must be valid before calling this
    def store_credit_card_offsite
      response = Freemium.gateway.store(self, :address => self.address, :billingid => self.billing_key)
      new_billing_key = response.params['billingid']

      #in prod transfirst will return successful, even though cvv fails
      #in QA, same case returns non-successful

      #TODO: check address and other fields here
      if Freemium.cvv_check
        cvv_failure = response.cvv_result.nil? || (response.cvv_result["code"] != "M")
      else
        cvv_failure = false
      end

      #raise "#{cvv_failure} : #{response.cvv_result.inspect}"
      if response.success? && (cvv_failure == false)
        @storage_failure=nil
      else
        begin
          Freemium.gateway.unstore(new_billing_key) if new_billing_key.present?
        rescue => error
          Freemium.mailer.deliver_background_error(error,
            {
              :billing_key => new_billing_key
            }, "Freemium::CreditCard#store_credit_card_offsite--rollback")
        end
        #regular failure is more important than cvv failure
        if ! response.success?
          @storage_failure=:number
          raise Freemium::CreditCardStorageError.new(@storage_failure,response.message,response)
        else
          @storage_failure=:verification_value
          raise Freemium::CreditCardStorageError.new(@storage_failure,"Bad CVV",response)
        end
      end
      #if we are updating, we have and send a billing key but,
      #  they dont return it - so we dont want to clear it out (hence the check for presence)
      self.billing_key = new_billing_key if new_billing_key.present?
      @trustee = true
      true
    end

    def cancel_in_remote_system
      if self.billing_key
        Freemium.gateway.unstore(self.billing_key)
        self.billing_key = nil
      end
    end

    def last4
      display_number.present? ? display_number[-4,4] : nil
    end

    #copy across the credit card details
    def populate_from_cc(new_credit_card)
      #clear derived fields
      self.display_number=nil
      self.expiration_date=nil

      REMOTE_FIELDS.each do |f|
        #double rescue so it will read from hashes or records
        value=new_credit_card.send(f) rescue new_credit_card[f] rescue nil
        self.send("#{f}=",value)
      end
      #NOTE: if first and last name are populated, will populate name attribute too
      #@name=nil if first_name? && last_name?
    end
  end
end