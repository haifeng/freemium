require File.dirname(__FILE__) + '/../test_helper'

class SubscriptionPlanTest < ActiveSupport::TestCase
  # def test_associations
  #   assert_equal [freemium_subscriptions(:paid_subscription)], freemium_subscription_plans(:basic).subscriptions
  # end

  def test_rate_intervals
    plan = FreemiumSubscriptionPlan.new(:rate_cents => 3041, :duration => '1M')
    assert_equal Money.new(99), plan.daily_rate
    assert_equal Money.new(3041), plan.monthly_rate
    assert_equal Money.new(36492), plan.yearly_rate
  end

  def test_creating_plan
    plan = Factory(:paid_plan)
    assert !plan.new_record?, plan.errors.full_messages.to_sentence
  end

  def test_missing_fields
    [:name, :rate_cents].each do |field|
      assert_raises ActiveRecord::RecordInvalid do
        Factory(:paid_plan, field => nil)
      end
    end
  end
  
  def test_next_plan_renewable
    plan=Factory(:paid_plan)
    assert_equal plan.next_plan, plan
  end

  def test_next_plan_non_renewable
    #Freemium.expired_plan=create_plan
    plan=Factory(:paid_plan, :renewable => false)
    #assert_equal Freemium.expired_plan, plan.next_plan
    ## threre is no "next plan" in store, so just return a null. subscription will swap with expired plan
    assert_equal nil, plan.next_plan
  end

  def test_next_plan_non_expires
    #Freemium.expired_plan=create_plan
    plan=Factory(:paid_plan, :duration => nil)
    assert_equal plan, plan.next_plan
  end

  ##
  ## Feature sets
  ##

  # def test_free_has_ads
  #   assert_equal true, Factory(:free_plan).feature_set.ads?
  # end
end