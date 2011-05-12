# == Attributes
#   subscribable:         the model in your system that has the subscription. probably a User.
#   subscription_plan:    which service plan this subscription is for. affects how payment is interpreted.
#   paid_through:         when the subscription currently expires, assuming no further payment. for manual billing, this also determines when the next payment is due.
#   billing_key:          the id for this user in the remote billing gateway. may not exist if user is on a free plan.
#   last_transaction_at:  when the last gateway transaction was for this account. this is used by your gateway to find "new" transactions.
#   expires_on:           we give them grace, so this states when we turn their functionality off
#
#   next_subscription_plan the plan that we will sign them up when renewing
module Freemium
  module Subscription
    include Rates
    include Freemium::DurationString

    def self.included(base)
      base.class_eval do
        #belongs_to :subscription_plan, :class_name => "FreemiumSubscriptionPlan"
        belongs_to :subscribable, :polymorphic => true
        #belongs_to :credit_card, :dependent => :destroy, :class_name => "FreemiumCreditCard"
        #has_many :coupon_redemptions, :conditions => "freemium_coupon_redemptions.expired_on IS NULL", :class_name => "PromotionRedemption", :foreign_key => :subscription_id, :dependent => :destroy
        has_many :coupons, :through => :coupon_redemptions

        # Auditing
        #has_many :transactions, :class_name => "FreemiumTransaction", :foreign_key => :subscription_id
        #has_many :subscription_changes, :class_name => "FreemiumSubscriptionChange", :as => :subscribable

        #TODO: get table name out of query - use something like #{subscription_plan.class.table_name}
        #these are the subscriptions that 'can' expire
        named_scope :expirable, :include => [:subscription_plan], :conditions => "freemium_subscription_plans.duration is not null"

        # plan due to be renewed
        named_scope :due, lambda {
          {
            :conditions =>  ['paid_through <= ?', Date.today] # could use the concept of a next retry date
          }
        }
        named_scope :expired, lambda {
          {
            :conditions => ['expire_on >= paid_through AND expire_on <= ?', Date.today]
          }
       }

        named_scope :trial_ends_soon, lambda {
          {:conditions => ["in_trial = 1 AND paid_through <= ?", Date.today + 5.days]}
        }

        before_validation_on_create :start_free_trial
        before_validation :set_paid_through
        before_validation :set_started_on
        before_save :store_credit_card_offsite
        before_save :discard_credit_card_unless_paid
        before_destroy :cancel_in_remote_system

        after_create  :audit_create
        after_update  :audit_update
        after_destroy :audit_destroy

        validates_presence_of :subscribable #, unless => Proc.new {|s| s.new_record?}
        #validates_associated  :subscribable
        validates_presence_of :subscription_plan
        validates_presence_of :paid_through, :if => :expires?
        validates_presence_of :started_on
        validates_presence_of :credit_card, :if => :require_credit_card?
        validates_associated  :credit_card, :if => :require_credit_card?

        #TODO: introduce gateway credit card validation
        #validate :gateway_validates_credit_card
      end
      base.extend ClassMethods
    end

    def original_paid_through
      self.changes['paid_through'].try('last')
    end

    def original_plan
      #TODO: can we get model name out of here?
      @original_plan ||= FreemiumSubscriptionPlan.find_by_id(subscription_plan_id_was) unless subscription_plan_id_was.nil?
    end

    def replace_credit_card(new_credit_card)
      begin
        self.credit_card.populate_from_cc(new_credit_card)
        self.credit_card.save
      rescue Freemium::CreditCardStorageError
        self.credit_card.destroy
        raise
      end
    end

    protected

    ##
    ## Validations
    ##

    def gateway_validates_credit_card
      if credit_card && credit_card.changed? && credit_card.valid?
        #TODO: introduce gateway credit card validation
        # response = Freemium.gateway.validate(credit_card, credit_card.address)
        # unless response.success?
        #   errors.add_to_base("Credit card could not be validated: #{response.message}")
        # end
        unless credit_card.valid?
          errors.add_to_base("Credit card could not be validated: #{credit_card.errors.full_messages}")
        end
      end
    end

    ##
    ## Callbacks
    ##

    def start_free_trial
      if Freemium.days_free_trial > 0 && paid?
        # paid + new subscription = in free trial
        self.paid_through = Date.today + Freemium.days_free_trial
        self.in_trial = true
      end
    end

    def set_paid_through
      if subscription_plan_id_changed? && !paid_through_changed?
        # if the plan has a duration and expires, then set paid_through.
        # paid through is a liberal definition
        if expires?
          if ! self.subscription_plan.paid? #beta doesn't cost anything, but it expires
            self.paid_through = Date.today
            self.in_trial = false
          elsif new_record?
            # paid + new subscription = in free trial
            self.paid_through = Date.today + Freemium.days_free_trial
            if Freemium.days_free_trial > 0
              self.in_trial = true
            else
              self.in_trial = false
            end
          elsif !self.in_trial? && self.original_plan && self.original_plan.paid?
            # paid + not in trial + not new subscription + original sub was paid = calculate and credit for remaining value
            # note: instead, we set the future plan to add AFTER this has expired. so this use case is not followed
            value = self.remaining_value(original_plan)
            self.paid_through = Date.today
            self.credit(value)
          else
            # otherwise payment is due today
            self.paid_through = Date.today
            self.in_trial = false
          end
        else
          # don't track plans that don't expire free plans don't pay
          self.paid_through = nil
          self.in_trial = false
        end
      end
      true
    end

    def set_started_on
      self.started_on = Date.today if subscription_plan_id_changed?
      true
    end

    # the next date we can charge them (on plan change)
    # so if a user has a plan that doesn't expire, we will change and charge today
    def next_charge_date
      self.paid_through||Date.today
    end

    # Simple assignment of a credit card. Note that this may not be
    # useful for your particular situation, especially if you need
    # to simultaneously set up automated recurrences.
    #
    # Because of the third-party interaction with the gateway, you
    # need to be careful to only use this method when you expect to
    # be able to save the record successfully. Otherwise you may end
    # up storing a credit card in the gateway and then losing the key.
    #
    # NOTE: Support for updating an address could easily be added
    # with an "address" property on the credit card.

    def store_credit_card_offsite
      # credit card would have been saved already. so can assume:
      # a) credit_card.valid?, stored in gateway, succeeded
      # b) credit card is not stored
      # c) credit card is not changed
      if credit_card && credit_card.changed? && credit_card.valid?
        self.expire_on = nil
        #TODO: this should not be necessary (since it was already saved before calling this method)
        self.credit_card.save
        self.credit_card.reload # to prevent needless subsequent store() calls
      end
      true
    end
    
    def discard_credit_card_unless_paid
      if ! store_credit_card? && Freemium.destroy_credit_card_for_free_accounts
        destroy_credit_card
      end
      true
    end

    def destroy_credit_card
      #credit_card.destroy if credit_card
      cancel_in_remote_system
    end

    def cancel_in_remote_system
      #unstore the card
      self.credit_card.destroy if credit_card
      self.credit_card=nil
      true
    end

    ##
    ## Callbacks :: Auditing
    ##

    def audit_create
      subscription_changes.create(:reason => "new",
                                        :subscribable => self.subscribable,
                                        :new_subscription_plan_id => self.subscription_plan_id,
                                        :new_rate => self.rate,
                                        :original_rate => Money.empty)
    end

    def audit_update
      if self.subscription_plan_id_changed?
        return if self.original_plan.nil?
        reason = self.expired? ? "expiration" : (self.original_plan.rate > self.subscription_plan.rate ? "downgrade" : "upgrade")
        subscription_changes.create(:reason => reason,
                                          :subscribable => self.subscribable,
                                          :original_subscription_plan_id => self.original_plan.id,
                                          :original_paid_through => self.original_paid_through,
                                          :original_rate => self.rate(:plan => self.original_plan),
                                          :new_subscription_plan_id => self.subscription_plan.id,
                                          :new_rate => self.rate)
      end
    end

    def audit_destroy
      subscription_changes.create(:reason => "cancellation",
                                        :subscribable => self.subscribable,
                                        :original_subscription_plan_id => self.subscription_plan_id,
                                        :original_paid_through => self.paid_through,
                                        :original_rate => self.rate,
                                        :new_rate => Money.empty)
    end

    public

    ##
    ## Class Methods
    ##

    module ClassMethods
      # expires all subscriptions that have been pastdue for too long (accounting for grace)
      def expire
        self.expired.each(&:expire!)
      end
    end

    ##
    ## used by rate
    ##

    def rate(options = {})
      options = {:date => Date.today, :plan => self.subscription_plan}.merge(options)
      return nil unless options[:plan]

      plan = options[:plan]
      date = options[:date]
      PromotionRedemption.determine_rate(self.coupon_redemptions, plan, date).rate
    end

    def duration
      self.subscription_plan.duration
    end

    # Allow for more complex logic to decide if a card should be stored
    def store_credit_card?
      subscription_plan.requires_credit_card?
      #paid?
    end

    # the plan needs to be renewed to keep current
    def expires?
      self.subscription_plan && self.subscription_plan.expires?
    end

    #is this record valid without a credit card?
    #if the subscription is free or expired, then valid without credit card
    def require_credit_card?
      (self.expire_on.nil? || self.expire_on > Date.today) && paid?
    end
    ##
    ## Coupon Redemption
    ##

    #TODO: move this out of here
    def coupon_key=(coupon_key)
      @coupon_key = coupon_key ? coupon_key.downcase : nil
      self.coupon = Promotion.find_by_promotion_code(@coupon_key) unless @coupon_key.blank?
    end

    #TODO: remove table reference
    def validate
      self.errors.add :coupon, "could not be found for '#{@coupon_key}'" if !@coupon_key.blank? && Promotion.find_by_promotion_code(@coupon_key).nil?
    end

    def coupon=(coupon)
      if coupon
        #TODO: coupon_redemptions.create(:coupon => coupon)
        s = PromotionRedemption.new(:subscription => self, :coupon => coupon)
        coupon_redemptions << s
      end
    end

    def coupon(date = Date.today)
      PromotionRedemption.choose_redemption(self.coupon_redemptions,date).try(:coupon) #rescue nil
    end

    ##
    ## Remaining Time
    ##

    # returns the value of the time between now and paid_through.
    # will optionally interpret the time according to a certain subscription plan.
    def remaining_value(plan = self.subscription_plan)
      _remaining_days = remaining_days
      _remaining_days > 0 ?  self.daily_rate(:plan => plan) * _remaining_days : Money.empty
    end

    # if paid through today, returns zero
    def remaining_days
      self.paid_through - Date.today
    end

    ##
    ## Grace Period
    ##

    # if under grace through today, returns zero
    def remaining_days_of_grace
      self.expire_on - Date.today - 1
    end

    def in_grace?
      (not expired?) && (remaining_days < 0)
    end

    ##
    ## Expiration
    ##

    # sets the expiration for the subscription based on today and the configured grace period.
    def expire_after_grace!(transaction = nil)
      return unless self.expire_on.nil? # You only set this once subsequent failed transactions shouldn't affect expiration
      self.expire_on = [Date.today, paid_through].max + Freemium.days_grace
      transaction.message = "#{transaction.message}: now set to expire on #{self.expire_on}" if transaction
      #do not send the warning email if there is no grace period
      Freemium.mailer.deliver_expiration_warning(self) if Freemium.days_grace > 0
      transaction.save! if transaction
      save!
    end

    # sends an expiration email, then downgrades to a free plan
    def expire!
      Freemium.mailer.deliver_expiration_notice(self)
      # downgrade to a free plan
      self.expire_on = Date.today
      old_plan=self.subscription_plan
      self.subscription_plan = Freemium.expired_plan if Freemium.expired_plan
      #save should be doing this
      #self.destroy_credit_card if Freemium.destroy_credit_card_for_free_accounts
      if old_plan.premium?
        self.subscription_histories.create_from_subscription(self, nil, nil, old_plan)
      end
      self.save!

      # #make sure account gets updated status
      self.account.transfer_subscription_details(self)
      self.account.save
    end

    def expired?
      expire_on ? expire_on <= Date.today : false
    end

    ##
    ## Receiving More Money
    ##

    # receives payment and saves the record
    def receive_payment!(transaction)
      receive_payment(transaction)
      transaction.save!
      self.save!
    end

    # extends the paid_through period according to how much money was received.
    # when possible, avoids the days-per-month problem by checking if the money
    # received is a multiple of the plan's rate.
    #
    # really, i expect the case where the received payment does not match the
    # subscription plan's rate to be very much an edge case.
    def receive_payment(transaction)
      self.credit(transaction.amount)
      self.save!
      transaction.subscription.reload  # reloaded to that the paid_through date is correct
      transaction.message = "#{transaction.message}: now paid through #{self.paid_through}"

      begin
        Freemium.mailer.deliver_invoice(transaction)
      rescue => error
        transaction.message = "#{transaction.message}: error sending invoice"
        Freemium.mailer.deliver_background_error(error,
          {
            :transaction_id => transaction.id,
            :account_id => self.subscribable_id,
          }, "Freemium::Subscription#receive_payment")
      end
    end

    # credit takes the amount of money charged, it then calculates the number of cycles or sub cycles
    # and assigning the paid_through accordingly
    # TODO: handle rates in something other then months

    def credit(amount)
      # if they are paid through a certain date - then increment it
      # paid through will not be present if the plan does not expire
      if self.paid_through.present?
        if rate.blank? || rate.zero?
          self.paid_through += subscription_plan.duration_days
        elsif amount.cents % rate.cents == 0
          self.paid_through += subscription_plan.duration_days * (amount.cents / rate.cents)
        else
          self.paid_through += 1.days * (amount.cents / daily_rate.cents)  # * subscription_plan.duration_days
        end
      end

      # if they've paid again, then reset expiration
      self.expire_on = nil
      self.in_trial = false
    end

    def next_plan
      if self.renewable?
        np ||= self.next_subscription_plan
        np ||= self.subscription_plan.next_plan
        np ||= Freemium.expired_plan
        np
      else
        Freemium.expired_plan
      end
    end

    # next_subscription_plan stores the next plan to assign to a user after renew
    #
    # the subscription_plan states the next possible plan. but ultimatly the user
    # decides if they want to auto renew
    #
    # this will cycle through the plans.
    #
    def assign_next_plan
      self.subscription_plan=self.next_plan||Freemium.expired_plan
      self.next_subscription_plan=nil
    end

    #when someone confirms their email, we make them free (unless they are free/paid)
    def make_free
      self.subscription_plan=Freemium.expired_plan #FreemiumSubscriptionPlan.free
    end

    # when renewing, sometimes the plan needs to be tweaked
    # counters change, plans change. called before billing a renew
    def rollback_next_plan(previous_plan)
      self.next_subscription_plan_id=self.subscription_plan_id
      self.subscription_plan=previous_plan
      #put custom logic in here
    end

    #either set next plan or current plan
    #returns:
    #  transaction if charged
    #  nil if no charge needed
    #  false if tried to charge, but failed
    #NOTE: need to call transfer_subscription_details afterwards
    def change_plan(new_plan, coupon=nil)
      #TODO: do we want to switch from alpha?
      if self.subscription_plan.expires? #add it after the current one expires?
        self.next_subscription_plan=new_plan
        if ! self.save
          return false
        end
        
        # if the coupon has not been applied yet to the account
        # (if it has, just go with the flow)
        if coupon && self.coupon_redemptions.given(:coupon_id => coupon.id).empty?
          self.coupon_redemptions.create(:coupon => coupon, :redeemed_on => self.paid_through)
        end
        self.save && nil
      else
        #typical use case: going from 'free' to a paid plan
        #but could be from 'free' to 'alpha' (free w/ different privs)
        old_plan = self.subscription_plan
        old_paid_through = self.paid_through

        self.subscription_plan=new_plan
        success = self.save
        if ! success
          return false
        end

        if coupon && self.coupon_redemptions.given(:coupon_id => coupon.id).empty?
          self.coupon_redemptions.create(:coupon => coupon, :redeemed_on => Date.today)
          #if it couldn't save the coupon - not sure if this is a failing matter
          if ! self.save
            #success=false
          end
        end
        #if success is false - don't charge
        if success
          tran=self.charge!
        else
          tran=false
        end

        #if we did not successfully charge - then set the plan back
        if tran == false || (tran.try(:success?) == false)
          self.subscription_plan=old_plan
          self.paid_through=old_paid_through
          self.save!
        end
        #if we did not charge them, or we charged them (tran != false) and the charge was successful
        #then audit the transaction
        if tran.nil? || tran.try(:success?)
          self.subscription_histories.create_from_subscription(self, coupon, tran, old_plan)
        end
        tran
      end
    end

    # seems to work better if the admin refunds the transaction - then changes the plan
    # (rather than automated)
    # def refund(amount=nil)
    #   #find the last transaction - and refund it
    #   self.transactions.last.refund(amount)
    #   #find the last subscription_histories entry - and mark it as an out
    #   self.subscript_histories.last.update_attributes(:category => )
    # end

    def due?
      self.paid_through.present? && self.paid_through<=Date.today
    end

    def has_promotion(coupon)
      self.coupon_redemptions.given(:coupon_id => coupon.id).last
    end
  end
end