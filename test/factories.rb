
#user is equivalent to account (so putting up at the top and not alphabetical)
Factory.define :user do |u|
  u.sequence(:name) { |n| "user#{n}" }
  u.email           { |u| "#{u.name}@example.com" }
end

#note: can't assign billing_key via mass assignment
Factory.define :credit_card, :class => FreemiumCreditCard, :default_strategy => :build do |cc|
  cc.name                          { "Santa Claus" }
  cc.address1                      { '1 North Pole' }
  cc.city                          { 'Polar Circle' }
  cc.state                         { 'NJ' }
  cc.zip_code                      { '22222' }
  cc.card_type                     { "visa" }
  cc.number                        { "4111111111111111" }
  cc.month                         { 10 }
  cc.year                          { 2010 }
  cc.verification_value            { 999 }
end

Factory.define :promotion do |promo|
  promo.sequence(:name)            { |n| "promo#{n}" }
  promo.description                { "promotion" }
  promo.discount_percentage        { 20 }
#  promo.auto_promotion             { false }
  promo.duration                   { "3M" }
end

Factory.define :free_subscription, :class => FreemiumSubscription do |subscription|
  subscription.subscribable        { Factory(:user) }
  subscription.subscription_plan   { Factory(:free_plan) }
  subscription.started_on          { Date.today - 60.days }
  subscription.in_trial            { false }
end

#bob = basic
Factory.define :paid_subscription, :parent => :free_subscription do |subscription|
  subscription.subscription_plan   { Factory(:paid_plan) }
  subscription.credit_card         { Factory(:credit_card) }
  subscription.paid_through        { (Date.today + 20.days).to_s :db }
  subscription.started_on          { (Date.today - 60.days).to_s :db }
  #last_transaction_at
end

Factory.define :free_plan, :class => FreemiumSubscriptionPlan do |plan|
  plan.sequence(:name)    { |n| "plan#{n}" }
  plan.redemption_key     { |sp| sp.name }
  plan.rate_cents         { 0 }
  plan.renewable          { true }
  plan.duration           { nil }
  plan.feature_set        { |sp| FreemiumFeatureSet.find_by_name('free') }
end

Factory.define :paid_plan, :parent => :free_plan do |plan|
  plan.duration           { "1M" } #default duration = "1M"
  plan.rate_cents         { 1300 }
  plan.feature_set        { |sp| FreemiumFeatureSet.find_by_name('paid') }
end
