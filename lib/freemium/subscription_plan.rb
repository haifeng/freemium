# == Attributes
#   subscriptions:      all subscriptions for the plan
#   rate_cents:         how much this plan costs, in cents
#   rate:               how much this plan costs, in Money
#   feature_set_id      reference to feature set
#   duration:           how often this plan cycles
#   renewable:          whether this plan can be renewed
#   next_subscription_plan_id: populated if it renews to a plan other than this plan
#
module Freemium
  # the plans that are available
  module SubscriptionPlan
    include Rates
    include Freemium::DurationString
    
    def self.included(base)
      base.class_eval do
        # yes, subscriptions.subscription_plan_id may not be null, but
        # this at least makes the delete not happen if there are any active.
        # has_many :subscriptions, :dependent => :nullify, :class_name => "FreemiumSubscription", :foreign_key => :subscription_plan_id
        # has_and_belongs_to_many :coupons, :class_name => "FreemiumSubscriptionPlan", 
        #   :join_table => :freemium_coupons_subscription_plans, :foreign_key => :subscription_plan_id, :association_foreign_key => :coupon_id
        
        composed_of :rate, :class_name => 'Money', :mapping => [ %w(rate_cents cents) ], :allow_nil => true
        
        validates_uniqueness_of :redemption_key, :allow_nil => true, :allow_blank => true
        validates_presence_of :name
        validates_presence_of :rate_cents
        validates_presence_of :feature_set_id
        #validates_presence_of :renewable (value of false fails.)
        before_validation     :set_duration
      end
    end

    def set_duration
      self.duration=nil if duration.blank?
      self.duration=self.duration.upcase if self.duration.respond_to?(:upcase)
    end

    def requires_credit_card?
      #TODO:
      self.rate_cents > 0
    end

    # a plan can either go forever, or it can have a term limit
    # true means this expires and needs to be renewed - e.g.: beta, $20/month
    # false means that it never expires - e.g.: free, alpha


    # # would have liked to only have next_subscription_plan_id acting as renewable flag, but
    # # got a little tricky to assign the id when the record was created. Had to double save
    # # the record on creation. Also had to keep a temporary @renewable around
    # def next_plan_id
    #   if self.expires?
    #     if self.renewable?
    #       self.next_subscription_plan_id || self.id
    #     else
    #       Freemium.expired_plan.id
    #     end
    #   else #shouldn't be calling next_plan_id ...
    #     self.id
    #   end
    # end

    def to_label
      name
    end
  end
end