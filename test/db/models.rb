#subscribable
class User < ActiveRecord::Base
  has_many :subscriptions, :as => :subscribable, :class_name => "FreemiumSubscription"
  has_one :subscription, :class_name => 'FreemiumSubscription', :as => :subscribable
  has_one :subscription_plan, :class_name => "FreemiumSubscriptionPlan", :through => :subscription
  has_many :subscription_plan_changes, :class_name => "FreemiumSubscriptionChange", :as => :subscribable
end

#just use the migration classes out of the box
MODELS_DIR=File.dirname(__FILE__) + '/../../generators/freemium_migration/templates/app/models/'

%w(freemium_credit_card
promotion
promotion_redemption
freemium_feature_set
freemium_subscription
freemium_subscription_change
freemium_subscription_plan
freemium_transaction
).each do |model|
  require MODELS_DIR+model
end


