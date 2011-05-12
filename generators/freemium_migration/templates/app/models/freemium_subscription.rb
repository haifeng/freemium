# == Schema Information
# Schema version: 201001225114910
#
# Table name: freemium_subscriptions
#
#  id                        :integer(4)    not null, primary key
#  subscribable_id           :integer(4)    not null
#  subscribable_type         :string(255)   not null
#  credit_card_id            :integer(4)    
#  subscription_plan_id      :integer(4)    not null
#  paid_through              :date          
#  expire_on                 :date          
#  started_on                :date          
#  last_transaction_at       :datetime      
#  in_trial                  :boolean(1)    not null
#  next_subscription_plan_id :integer(4)    
#  renewable                 :boolean(1)    default(TRUE)
#

class FreemiumSubscription < ActiveRecord::Base
  belongs_to :subscription_plan, :class_name => "FreemiumSubscriptionPlan"
  belongs_to :next_subscription_plan, :class_name => "FreemiumSubscriptionPlan"
  #belongs_to :subscribable, :polymorphic => true
  belongs_to :credit_card, :dependent => :destroy, :class_name => "FreemiumCreditCard", :foreign_key => 'credit_card_id'
  has_many :coupon_redemptions, :conditions => "promotion_redemptions.expired_on IS NULL", :class_name => "PromotionRedemption", :foreign_key => :subscription_id, :dependent => :destroy
  #has_many :coupons, :through => :coupon_redemptions, :conditions => "freemium_coupon_redemptions.expired_on IS NULL"

  # Auditing
  has_many :transactions, :class_name => "FreemiumTransaction", :foreign_key => :subscription_id
  has_many :subscription_changes, :class_name => "FreemiumSubscriptionChange", :as => :subscribable

  include Freemium::Subscription
  include Freemium::ManualBilling # We need to include this manually

  #ours

end