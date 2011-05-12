module Freemium
  #tracks changes in subscription like becoming free / paid
  module SubscriptionChange

    def self.included(base)
      base.class_eval do
        belongs_to :subscribable, :polymorphic => true

        #belongs_to :original_subscription_plan, :class_name => "FreemiumSubscriptionPlan"
        #belongs_to :new_subscription_plan, :class_name => "FreemiumSubscriptionPlan"

        composed_of :new_rate, :class_name => 'Money', :mapping => [ %w(new_rate_cents cents) ], :allow_nil => true
        composed_of :original_rate, :class_name => 'Money', :mapping => [ %w(original_rate_cents cents) ], :allow_nil => true

        validates_presence_of :reason
        validates_inclusion_of :reason, :in => %w(new upgrade downgrade expiration cancellation)
      end
    end

  end
end