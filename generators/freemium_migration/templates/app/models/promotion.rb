# == Schema Information
# Schema version: 201001225114910
#
# Table name: promotions
#
#  id                    :integer(4)    not null, primary key
#  description           :string(255)   not null
#  discount_percentage   :integer(4)    not null
#  promotion_code        :string(255)   
#  redemption_limit      :integer(4)    
#  redemption_expiration :date          
#  duration              :string(4)     
#  name                  :string(255)   
#  plan_set_id           :integer(4)    
#

class Promotion < ActiveRecord::Base
  has_many :coupon_redemptions, :dependent => :destroy, :class_name => "PromotionRedemption", :foreign_key => :coupon_id
  #has_many :subscriptions, :through => :coupon_redemptions
  has_and_belongs_to_many :subscription_plans, :class_name => "FreemiumSubscriptionPlan", 
    :join_table => :freemium_coupons_subscription_plans, :foreign_key => :coupon_id, :association_foreign_key => :subscription_plan_id
  include Freemium::Coupon
  #this defined duration_days, duration_in_months, ...
  include Freemium::DurationString

  validates_presence_of :name
  validates_presence_of :description
  validates_presence_of :discount_percentage
  validates_numericality_of :discount_percentage, :greater_than_or_equal_to => 0, :less_than_or_equal_to => 100, :only_integer => true
  def before_validation
    self.duration=self.duration.upcase if self.duration.respond_to?(:upcase)
  end
end
