# == Schema Information
# Schema version: 201001225114910
#
# Table name: freemium_subscription_changes
#
#  id                            :integer(4)    not null, primary key
#  subscribable_id               :integer(4)    not null
#  subscribable_type             :string(255)   not null
#  original_subscription_plan_id :integer(4)    
#  new_subscription_plan_id      :integer(4)    
#  reason                        :string(255)   not null
#  created_at                    :datetime      not null
#

class FreemiumSubscriptionChange < ActiveRecord::Base
  belongs_to :original_subscription_plan, :class_name => "FreemiumSubscriptionPlan"
  belongs_to :new_subscription_plan, :class_name => "FreemiumSubscriptionPlan"
  include Freemium::SubscriptionChange
end
