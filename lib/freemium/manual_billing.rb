module Freemium
  # adds manual billing functionality to the Subscription class
  # manual billing means our program will tell the credit card company to charge a subscriber
  # alternate is recurring_billing
  module ManualBilling
    def self.included(base)
      base.extend ClassMethods
    end

    # # Override if you need to charge something different than the rate (ex: yearly billing option)
    # def installment_amount
    #   #PromotionRedemption.determine_rate(coupons,plan,redemption_rate)
    #   self.rate(options)
    # end

    # charges this subscription.
    # assumes, of course, that this module is mixed in to the Subscription model
    # NOTE: need to save before calling charge!
    def charge!
      if ! self.paid? #plan is free, or coupon covers full cost
        #bypass cc transaction stuff, just credit the account
        #if it expires, or doesn't - credit and clear out expires
        self.credit(0)
        self.save!
        return nil #did not charge
      end

      #would feel more comfortable if we knew the components of the rate (rather than deriving each in a different way)
      installment_amount = self.rate
      #aka:
      ##PromotionRedemption.determine_rate(self.coupon_redemptions, self.subscription_plan, Date.today).rate
      promotion = PromotionRedemption.choose_redemption(self.coupon_redemptions,Date.today).try(:coupon)

      response=Freemium.purchase(installment_amount, self.credit_card)
      @transaction = self.transactions.create(response.merge({
        # NOTE: these next 3 are implicitly included
        #       so we don't need them here
        #:amount          => fee_cents,    (from response)
        #:success         => true,         (from response)
        #:person_id                        (implied from FreemiumSubscription#transactions extends)
        :purchase         => subscription_plan,
        :promotion        => promotion,
        :revenue_recognized_start =>self.paid_through,
        :revenue_recognized_end   =>self.paid_through + subscription_plan.duration_days - 1.day
      }))

      # TODO this could probably now be inferred from the list of transactions
      self.last_transaction_at = Time.now.utc
      #if the transaction worked, then this user has officially paid us money for a subscription
      if @transaction.try(:success?)
        self.first_paid||=Date.today
      end
      self.save(false)
    
      #TODO: do we want this empty try/catch?
      begin
        if @transaction.success? 
          receive_payment!(@transaction)
          self.notify_refmob # Will only notify them if appropriate
        else
          if !@transaction.subscription.in_grace?
            expire_after_grace!(@transaction)
          end
          raise "Transaction failed"
        end
      rescue => error
        Freemium.mailer.deliver_background_error(error,
          {
            :amount => installment_amount.format,
            (self.subscribable.class.to_s.underscore+"_id").to_sym=> subscribable_id,
            :subscription_plan_id => self.subscription_plan_id,
            :transaction => @transaction
          }, "Freemium::ManualBilling#charge!")
      end
      
      @transaction
    end

    # renew this subscription
    # used to only have charge - but that made assumptions that the user wanted to be renewed
    # call this method instead which will only charge if the user wants to be charged (or the plan can be charged)
    # this is only called on plans that are expirable
    def renew!
      #use this to roll back (if the new plan does not take effect)
      old_plan=self.subscription_plan
      #charge at the new rate
      self.assign_next_plan
      self.save!

      tran=nil

      # for a subscription, paid? takes into account (plan cost - coupon cost)
      # for a plan, paid? only takes into account the plan cost
      if self.subscription_plan(true) && self.paid? #money is due
        tran=self.charge! #transaction (won't be nil because money is due)

        if tran.try :success?
          self.subscription_histories.create_from_subscription(self, tran.promotion, tran, old_plan)
        else
          self.rollback_next_plan(old_plan)
          self.save!
        end
      elsif self.subscription_plan.expires?
        #their new plan is an expiring free plan (plan is always free, lasts a month, coupon makes free for a month)
        tran=self.charge! #nil
        self.subscription_histories.create_from_subscription(self, self.coupon, tran, old_plan)
      else
        self.subscription_histories.create_from_subscription(self, nil, nil, old_plan)
        #if they were paid, and they are free now (probably renew=false, now have non-premium account )
        # dont post money - it will expire
        tran=nil #no transaction
      end

      #make sure account gets updated status
      self.account.transfer_subscription_details(self)
      self.account.save

      tran
    end

    protected
    def active_merchant_trans_params(response, other_params={})
      #For the first charge, if there is no billing id, don't want to erase the new billing id with the previous (nil) value
      #other_params.delete(:billing_key) if other_params[:billing_key].blank?
      {
        :success                =>response.success?,
        :gateway_transaction_id =>response.params['transid'],
        #:amount_cents           =>response.params['paid_amount'].to_f * 100, # subscription
        :message                =>response.message
      }.merge(other_params)
    end

    module ClassMethods
      # the process you should run periodically
      def run_billing
        # charge all billable subscriptions
        @transactions = find_billable.collect { |b| b.renew! }

        # actually expire any subscriptions whose time has come
        expire

        #remove nil transactions - caused by accounts that didn't auto renew
        @transactions.compact!

        # send the activity report
        Freemium.mailer.deliver_admin_report(
          @transactions # Add in transactions
        ) if Freemium.admin_report_recipients && !@transactions.empty?

        # Warn users whose free trial is about to expire
        #
        # find_warn_about_trial_ending.each do |subscription|
        #   Freemium.mailer.deliver_trial_ends_soon_warning(subscription)
        #   subscription.sent_trial_ends = true
        #   subscription.save!
        # end
        
        @transactions
      end

      # def bill_just_one
      #   find_billable.first.charge!
      # end

      protected
      
      # a subscription is due on the last day it's paid through. so this finds all
      # subscriptions that expire the day *after* the given date. 
      # because of coupons we can't trust rate_cents alone and need to verify that the account is indeed paid?

      #NOTE: we need to run these through anyway, because the plan being charged (next plan) could
      # cost money while the current plan does not. (or it could change in other ways)
      def find_billable
        self.expirable.due
      end

      # def find_warn_about_trial_ending
      #   self.expirable.trial_ends_soon.scoped(:conditions => {:sent_trial_ends => false})
      # end
    end
  end
end