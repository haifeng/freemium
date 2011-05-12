# == Schema Information
# Schema version: 201001225114910
#
# Table name: freemium_subscription_plans
#
#  id                        :integer(4)    not null, primary key
#  name                      :string(255)   not null
#  redemption_key            :string(255)   not null
#  rate_cents                :integer(4)    not null
#  feature_set_id            :integer(4)    not null
#  next_subscription_plan_id :integer(4)    
#  duration                  :string(4)     default("1M")
#  renewable                 :boolean(1)    default(TRUE), not null
#  description               :string(255)   
#

class FreemiumSubscriptionPlan < ActiveRecord::Base

  has_many :tokens, :foreign_key => :plan_id, :class_name => "FreemiumToken" # This may be a worthless association -- why would you ever look it up this way? --mwagner
  has_many :subscriptions, :dependent => :nullify, :class_name => "FreemiumSubscription", :foreign_key => :subscription_plan_id
  has_and_belongs_to_many :coupons, :class_name => "Promotion",
    :join_table => :freemium_coupons_subscription_plans, :foreign_key => :subscription_plan_id, :association_foreign_key => :coupon_id
  #belongs_to :feature_set, :class_name => "FreemiumFeatureSet"

  belongs_to :next_subscription_plan, :class_name => "FreemiumSubscriptionPlan"

  include Freemium::SubscriptionPlan

  def before_validation
    self.redemption_key||=self.name
  end

  def feature_set
    FreemiumFeatureSet.find(self.feature_set_id)
  end

  def feature_set=(value)
    write_attribute(:feature_set_id,value.id)
    @feature_set=value
  end

  def feature_set_id=(value)
    @feature_set=nil
    write_attribute(:feature_set_id,value)
  end

  def next_plan
    if self.expires?
      if self.renewable?
        if next_subscription_plan_id==self.id || next_subscription_plan_id.nil?
          self
        else
          self.next_subscription_plan
        end
      else
        nil
      end
    else #shouldn't be calling next_plan ...
      self
    end
  end
end