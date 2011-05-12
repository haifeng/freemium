module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # Validation methods that can be included into a custom Credit Card object, such as an ActiveRecord based Credit Card object.
    module CreditCardValidations
      def self.included(base)
        base.extend         ClassMethods
        base.send :cattr_accessor,:require_verification_value
        base.send :require_verification_value=,true
        base.send :include, InstanceMethods
      end

      module ClassMethods
        def requires_verification_value?
          require_verification_value
        end
      end
  
      module InstanceMethods
#        def name?
#          @name.present? || first_name? && last_name?
#        end

#        def first_name?
#          first_name.present?
#        end
#
#        def last_name?
#          last_name.present?
#        end

        def verification_value?
          !verification_value.blank?
        end

        def validate_card_number #:nodoc:
          errors.add :number, "is not a valid credit card number" unless CreditCard.valid_number?(number)
          unless errors.on(:number) || errors.on(:type)
            errors.add :type, "is not the correct card type" unless CreditCard.matching_type?(number, card_type)
          end
        end

        def validate_card_type #:nodoc:
          errors.add :type, "is required" if card_type.blank?
          errors.add :type, "is invalid"  unless CreditCard.card_companies.keys.include?(card_type)
        end

        def validate_essential_attributes #:nodoc:
          #errors.add :first_name, "cannot be empty"      if self.first_name.blank?
          #errors.add :last_name,  "cannot be empty"      if self.last_name.blank?
          errors.add :name,       "cannot be empty"      if self.name.blank?
          errors.add :month,      "is not a valid month" unless valid_month?(self.month)
          errors.add :year,       "expired"              if expired?
          errors.add :year,       "is not a valid year"  unless valid_expiry_year?(self.year)
          errors.add :address1,   "address is required"  if self.address1.blank?
          errors.add :city,       "city is required"     if self.city.blank?
          errors.add :state,      "state is required"    if self.state.blank?
          errors.add :zip_code,   "zip code is required" if self.zip_code.blank?
        end

        def validate_switch_or_solo_attributes #:nodoc:
          if %w[switch solo].include?(card_type)
            unless valid_month?(self.start_month) && valid_start_year?(self.start_year) || valid_issue_number?(self.issue_number)
              errors.add :start_month,  "is invalid"      unless valid_month?(self.start_month)
              errors.add :start_year,   "is invalid"      unless valid_start_year?(self.start_year)
              errors.add :issue_number, "cannot be empty" unless valid_issue_number?(self.issue_number)
            end
          end
        end

        def validate_verification_value #:nodoc:
          if CreditCard.requires_verification_value?
            errors.add :verification_value, "is required" unless verification_value? 
          end
        end
        
        def validate_credit_card_data
          validate_essential_attributes

          # Bogus card is pretty much for testing purposes. Lets just skip these extra tests if its used
          return if card_type == 'bogus'

          validate_card_type
          validate_card_number
          validate_verification_value
          validate_switch_or_solo_attributes
        end

        def sanitize_credit_card_data #:nodoc: 
          self.month = month.to_i
          self.year  = year.to_i
          self.year+=2000 if self.year < 100
          self.start_month = start_month.to_i unless start_month.nil?
          self.start_year = start_year.to_i unless start_year.nil?
          self.number = number.to_s.gsub(/[^\d]/, "")
          self.card_type.downcase! if card_type.respond_to?(:downcase)
          #self.card_type = self.class.type?(number) if card_type.blank?
        end     
      end
    end
  end
end