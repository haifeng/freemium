module Freemium
  # a coupon that is applied to a subscriber
  # this stores the number of months left at a discount
  module CouponRedemption
    
    def self.included(base)
      base.class_eval do
        #belongs_to :subscription, :class_name => "FreemiumSubscription", :foreign_key => :subscription_id
        #belongs_to :coupon, :class_name => "FreemiumCoupon"
        
        before_validation :set_redeemed_on
        
        validates_presence_of :coupon
        validates_presence_of :subscription
        validates_uniqueness_of :coupon_id, :scope => :subscription_id, :message => "has already been applied"   
      end
      base.extend ClassMethods
    end

    module ClassMethods
      # Taken from subscription#coupon_redemption
      # choose the best coupon from a list of coupons
      def choose_redemption(redemption_list, date = Date.today)
        return nil if date.nil? # This is a nonsense case -- a non-expiring user with a coupon? But it happened locally, so we should protect against it. --mwagner
        return nil if redemption_list.blank?
        active_coupons = redemption_list.select{|c| c.active?(date)}
        return nil if active_coupons.blank?
        active_coupons.sort_by{|c| c.coupon.discount_percentage }.reverse.first
      end

      #given a list of coupons and a subscription, make coupon redemption records to be able to determine elgibility
      def choose_coupon(subscription, coupons, date = Date.today)
        choose_redemption(redemptions_for_coupons(subscription,coupons,date),date).try(:coupon)
      end

      # coupons = promotion_redemptions
      # plan: subscription_plans
      # redemption_date: date to charge
      def determine_rate(coupons,plan,date=Date.today)
        if coupons.is_a?(Promotion)
          promotion = coupons
        elsif coupons == nil
          coupons = nil
        else
          #promotion = coupons.first.try(:coupon)
          promotion = self.choose_redemption(coupons,date).try(:coupon)
        end

        if promotion && ! plan.daily?
          rate = promotion.discounted_rate(plan)
          #rate.round! unless rate.free? (#discounted_rate rounds for us)
        else
          rate = plan.dup
          rate.round! unless rate.free? || rate.duration_parts[1] == "days" #ROUND
        end
        rate
      end
    end

    def expire!
      self.update_attribute :expired_on, Date.today
    end  
    
    def active?(date = Date.today)
      eo=expires_on
      if eo #the coupon expires
        date < eo #it expires after the day applying
      else #doesn't expire
        true
      end
    end
    
    def expires_on
      return nil unless self.coupon.expires?
      self.redeemed_on + self.coupon.duration_days
    end
    
    def redeemed_on
      self['redeemed_on'] || Date.today
    end
    
    protected
    
    def set_redeemed_on
      self.redeemed_on = Date.today unless self['redeemed_on']
      #self.expired_on = self.expires? ? self.redeemed_on + self.coupon.duration_days : nil
    end
    
    def validate_on_create
      apply_date = self.subscription.paid_through||Date.today
      if apply_date <= Date.today
        apply_date = Date.today
#        plan_in_effect = self.subscription.subscription_plan
#      else
#        plan_in_effect = self.subscription.next_plan
      end
      ##errors.add :subscription,  "must be paid"             if self.subscription && !plan_in_effect.paid?
      errors.add :coupon,  "has expired"                    if self.coupon && self.coupon.expired?(apply_date)
      # errors.add :coupon,  "is not valid for selected plan" if self.coupon && plan_in_effect && !self.coupon.applies_to_plan?(plan_in_effect)
    end                  
  end
end