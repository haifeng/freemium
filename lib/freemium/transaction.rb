module Freemium

  ## credited: A boolean that should be set to 'true' for successful transactions after the subscription has been updated to reflect the new paid_through date

  ## A transaction is created for ever intereaction with the payment processor.
  module Transaction

    def self.included(base)
      base.class_eval do
        named_scope :since, lambda { |time| {:conditions => ["created_at >= ?", time]} }
        
        #belongs_to :subscription, :class_name => "FreemiumSubscription"
        belongs_to :purchase, :polymorphic => true #event or subscription
        belongs_to :promotion

        composed_of :amount, :class_name => 'Money', :mapping => [ %w(amount_cents cents) ], :allow_nil => true        
      end
    end

    # determine the rate for this transaction
    # return a DurationRate
    def rate_duration
      if self.purchase.is_a?(SubscriptionPlan)
        Freemium::RateDuration.new(:rate_cents => self.amount_cents, :duration => self.purchase.duration)
		  end
    end

    def non_discounted_rate_duration
      if self.promotion_id.blank?
        self.rate_duration
      elsif self.purchase.is_a?(SubscriptionPlan)
        self.purchase.rate_duration
		  end
    end
  end
end