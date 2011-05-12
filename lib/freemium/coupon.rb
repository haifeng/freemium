module Freemium
  #A coupon that provedes either a certain number of months at a percentage off, or a reduction of rate until a certain date
  module Coupon
    def self.included(base)
      base.class_eval do
        #has_many :coupon_redemptions, :dependent => :destroy, :class_name => "FreemiumCouponRedemption", :foreign_key => :coupon_id
        has_many :subscriptions, :through => :coupon_redemptions
        #has_and_belongs_to_many :subscription_plans, :class_name => "FreemiumSubscriptionPlan", 
        #  :join_table => :freemium_coupons_subscription_plans, :foreign_key => :coupon_id, :association_foreign_key => :subscription_plan_id
        
        validates_presence_of :description
        validates_inclusion_of :discount_percentage, :in => 0..100
        
        before_save :normalize_promotion_code
      end
    end
    
    # deprecated, use discounted_rate instead
    def discount(rate)
      rate * (1 - self.discount_percentage.to_f / 100)
    end

    #can take a rate_duration, subscription_plan, other?
    def discounted_rate(plan)
      #TODO: do we handle non monthly plans?
      #discount monthly rate
      new_rate = plan.rate() * (1 - self.discount_percentage.to_f / 100)

      new_rate_duration = RateDuration.new(:rate => new_rate, :duration => plan.duration)
      new_rate_duration.round! unless new_rate_duration.free?
      new_rate_duration
    end
    
    def expired?(date = Date.today)
      (self.redemption_expiration && date > self.redemption_expiration) || (self.redemption_limit && self.coupon_redemptions.count >= self.redemption_limit)
    end
    
    def applies_to_plan?(subscription_plan)
      return true if self.subscription_plans.blank? # applies to all plans
      self.subscription_plans.include?(subscription_plan)
    end
        
    protected
    
    def normalize_promotion_code
      self.promotion_code.downcase! unless self.promotion_code.blank?
    end    
        
  end
end