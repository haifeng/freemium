module Freemium
  # adds recurring billing functionality to the Subscription class
  # recurring billing means the credit card company will charge customers
  # disabled this class since it is not tested with an active merchant gateway
  # alternate is manual_billing
  module RecurringBilling
    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      # the process you should run periodically
      def xrun_billing
        # first, synchronize transactions
        transactions = process_transactions
        
        # then, set expiration for any subscriptions that didn't process
        find_expirable.each(&:expire_after_grace!)
        # then, actually expire any subscriptions whose time has come
        expire

        # send the activity report
        Freemium.mailer.deliver_admin_report(
          transactions
        ) if Freemium.admin_report_recipients && !new_transactions.empty?
      end

      protected

      # retrieves all transactions posted after the last known transaction
      #
      # please note how this works: it calculates the maximum last_transaction_at
      # value and only retrieves transactions after that. so be careful that you
      # don't accidentally update the last_transaction_at field for some subset
      # of subscriptions, and leave the others behind!
      def xnew_transactions
        Freemium.gateway.transactions(:after => self.maximum(:last_transaction_at))
      end

      # updates all subscriptions with any new transactions
      def xprocess_transactions(transactions = new_transactions)
        transaction do
          transactions.each do |transaction|
            subscription = FreemiumSubscription.find_by_billing_key(transaction.billing_key)
            subscription.transactions << transaction
            transaction.success? ? subscription.receive_payment!(transaction) : subscription.expire_after_grace!(transaction)
          end
        end
        transactions
      end

      # finds all subscriptions that should have paid but didn't and need to be expired
      # because of coupons we can't trust rate_cents alone and need to verify that the account is indeed paid?
      def find_expirable
        find(
          :all,
          :include => [:subscription_plan],
          #TODO: get table name out of query
          :conditions => ['freemium_subscription_plans.rate_cents > 0 AND paid_through < ? AND (expire_on IS NULL OR expire_on < paid_through)', Date.today]
        ).select{|s| s.paid?}
      end
    end
  end
end