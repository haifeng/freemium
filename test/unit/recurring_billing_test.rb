require File.dirname(__FILE__) + '/../test_helper'

class RecurringBillingTest < ActiveSupport::TestCase
#  fixtures :users, :freemium_subscriptions, :freemium_subscription_plans, :freemium_credit_cards

  class FreemiumSubscription < ::FreemiumSubscription
    include Freemium::RecurringBilling
  end

  def xtest_run_billing
    FreemiumSubscription.expects(:process_transactions).once
    FreemiumSubscription.expects(:find_expirable).once.returns([])
    FreemiumSubscription.expects(:expire).once
    FreemiumSubscription.run_billing
  end

  def xtest_run_billing_sends_report
    #TODO: create a user
    FreemiumSubscription.stubs(:process_transactions)
    Freemium.stubs(:admin_report_recipients).returns("test@example.com")

    Freemium.mailer.expects(:deliver_admin_report)
    FreemiumSubscription.run_billing
  end

  def xtest_subscriptions_to_expire
    # making a one-off fixture set, basically
    create_billable_subscription # this subscription qualifies
    create_billable_subscription(:subscription_plan => Factory(:free_plan)) # this subscription would qualify, except it's for the free plan
    create_billable_subscription(:paid_through => Date.today) # this subscription would qualify, except it's already paid
    create_billable_subscription(:coupon => Promotion.create!(:description => "Complimentary", :discount_percentage => 100)) # should NOT be billable because it's free
    s = create_billable_subscription # this subscription would qualify, except it's already been set to expire
    s.update_attribute :expire_on, Date.today + 1

    expirable = FreemiumSubscription.send(:find_expirable)
    assert expirable.all? {|subscription| subscription.paid?}, "free subscriptions don't expire"
    assert expirable.all? {|subscription| !subscription.in_trial?}, "subscriptions that have been paid are no longer in the trial period"
    assert expirable.all? {|subscription| subscription.paid_through < Date.today}, "paid subscriptions don't expire"
    assert expirable.all? {|subscription| !subscription.expire_on or subscription.expire_on < subscription.paid_through}, "subscriptions already expiring aren't included"
    assert_equal 1, expirable.size    
  end

  def xtest_processing_new_transactions
    subscription = freemium_subscriptions(:paid_subscription)
    subscription.coupon = Promotion.create!(:description => "Complimentary", :discount_percentage => 30)
    subscription.save!
    
    paid_through = subscription.paid_through
    t = FreemiumTransaction.new(:billing_key => subscription.credit_card.billing_key, :amount => subscription.rate, :success => true)
    FreemiumSubscription.stubs(:new_transactions).returns([t])

    # the actual test
    FreemiumSubscription.send :process_transactions
    assert_equal (paid_through + 1.month).to_s, subscription.reload.paid_through.to_s, "extended by two months"
  end

  def xtest_processing_a_failed_transaction
    subscription = freemium_subscriptions(:paid_subscription)
    paid_through = subscription.paid_through
    t = FreemiumTransaction.new(:billing_key => subscription.credit_card.billing_key, :amount => subscription.rate, :success => false)
    FreemiumSubscription.stubs(:new_transactions).returns([t])

    # the actual test
    assert_nil subscription.expire_on
    FreemiumSubscription.send :process_transactions
    assert_equal paid_through, subscription.reload.paid_through, "not extended"
    assert_not_nil subscription.expire_on
  end

  def xtest_all_new_transactions
    last_transaction_at = FreemiumSubscription.maximum(:last_transaction_at)
    method_args = FreemiumSubscription.send(:new_transactions)
    assert_equal last_transaction_at, method_args[:after]
  end

  protected

  def create_billable_subscription(options = {})
    FreemiumSubscription.create!({
      :subscription_plan => Factory(:paid_plan),
      :subscribable => User.new(:name => 'a'),
      :paid_through => Date.today - 1,
      :credit_card => Factory(:credit_card)
    }.merge(options))
  end
end