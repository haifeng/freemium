require File.dirname(__FILE__) + '/../test_helper'

class SubscriptionTest < ActiveSupport::TestCase
  def setup
    @paid_plan = Factory(:paid_plan) #Factory(:paid_plan)
    @free_plan = Factory(:free_plan)
  end

  def test_creating_free_subscription
    @free_plan = Factory(:free_plan)
    subscription = Factory.build(:free_subscription, :subscription_plan => @free_plan)
    subscription.save!

    assert !subscription.new_record?, subscription.errors.full_messages.to_sentence
    assert_equal Date.today, subscription.reload.started_on
    assert_equal false, subscription.in_trial?
    assert_nil subscription.paid_through
    assert !subscription.paid?

    assert_changed(subscription.subscribable, :new, nil, @free_plan)
  end

  def test_free_subscription
    @free_plan = Factory(:free_plan)
    assert_equal false, @free_plan.paid?
    assert_equal false, @free_plan.requires_credit_card?
    assert_equal false, @free_plan.expires?
    assert_nil @free_plan.duration_days
  end

  def test_assign_alpha_subscription
    subscription = Factory(:free_subscription)
    new_plan = Factory(:free_plan)
    assert_equal false, subscription.expires?
    assert_equal false, new_plan.expires?
    assert_nil subscription.change_plan(new_plan), subscription.errors.full_messages
    assert_nil subscription.paid_through
  end

  def test_assign_beta_subscription
    subscription = Factory(:free_subscription)
    new_plan = Factory(:free_plan, :renewable => false, :duration => '6M')
    assert_equal false, subscription.expires?
    assert new_plan.expires?
    assert_nil subscription.change_plan(new_plan), subscription.errors.full_messages
    assert_equal Date.today+6.months, subscription.paid_through
  end

  def test_assign_paid_subscription
    subscription = Factory(:free_subscription)
    new_plan = Factory(:paid_plan, :duration => '6M')
    assert_equal false, subscription.expires?
    assert new_plan.expires?
    
    #take user from free to paid

    subscription.credit_card=Factory(:credit_card)
    assert subscription.save
    assert_not_nil subscription.change_plan(new_plan), subscription.errors.full_messages
    assert_equal Date.today+6.months, subscription.paid_through
  end

  def test_paid_subscription
    @paid_plan = Factory(:paid_plan) #Factory(:paid_plan)
    assert @paid_plan.paid?
    assert @paid_plan.requires_credit_card?
    assert @paid_plan.expires?
    assert_equal 1.month, @paid_plan.duration_days
  end

  def test_creating_paid_subscription
    Freemium.days_free_trial = 30

    subscription = Factory.build(:free_subscription, :subscription_plan => @paid_plan, :credit_card => Factory(:credit_card))
    subscription.save!

    assert !subscription.new_record?, subscription.errors.full_messages.to_sentence
    assert_equal Date.today, subscription.reload.started_on
    assert_equal true, subscription.in_trial?, 'expecting to be in trial'
    assert_not_nil subscription.paid_through
    assert_equal Date.today + Freemium.days_free_trial, subscription.paid_through
    assert subscription.paid?
    assert_not_nil subscription.credit_card.billing_key

    assert_changed(subscription.subscribable, :new, nil, @paid_plan)
  end

  def test_upgrade_from_free
    subscription = Factory.build(:free_subscription,:subscription_plan => @free_plan)
    subscription.save!

    Timecop.travel(Time.now + 10.days) do
      assert_equal false, subscription.in_trial?
      subscription.subscription_plan = @paid_plan
      #TODO: dont set credit card but update instead
      subscription.credit_card = Factory(:credit_card)
      subscription.save!
    end

    assert_equal Date.today + 10.days, subscription.reload.started_on
    assert_not_nil subscription.paid_through
    assert_equal false, subscription.in_trial?
    assert_equal Date.today + 10.days, subscription.paid_through
    assert subscription.paid?
    assert_not_nil subscription.credit_card.billing_key

    assert_changed(subscription.subscribable, :upgrade, @free_plan, @paid_plan)
  end

  def test_downgrade_destroy_cc
    Freemium.destroy_credit_card_for_free_accounts=true
    subscription = Factory.build(:free_subscription, :subscription_plan => @paid_plan, :credit_card => Factory(:credit_card))
    subscription.save!

    old_cc = subscription.credit_card

    #TODO: ensure we killed the billing_key in the credit card
    Timecop.travel(Time.now + 10.days) do
      subscription.subscription_plan = @free_plan
      subscription.save!
    end

    assert_equal Date.today + 10.days, subscription.reload.started_on
    assert_nil subscription.paid_through
    assert !subscription.paid?
    assert_nil old_cc.billing_key
    assert_nil subscription.credit_card

    assert_changed(subscription.subscribable, :downgrade, @paid_plan, @free_plan)
  end

  def test_downgrade_no_destroy_cc
    Freemium.destroy_credit_card_for_free_accounts=false
    subscription = Factory.build(:free_subscription, :subscription_plan => @paid_plan, :credit_card => Factory(:credit_card))
    subscription.save!

    old_cc = subscription.credit_card

    #TODO: ensure we killed the billing_key in the credit card
    Timecop.travel(Time.now + 10.days) do
      subscription.subscription_plan = @free_plan
      subscription.save!
    end

    assert_equal Date.today + 10.days, subscription.reload.started_on
    assert_nil subscription.paid_through
    assert !subscription.paid?
    assert_not_nil old_cc.billing_key
    assert_not_nil subscription.credit_card

    assert_changed(subscription.subscribable, :downgrade, @paid_plan, @free_plan)
  end

  def test_associations
    subscription = Factory(:paid_subscription)
    #assert_equal users(:bob), subscription.subscribable
    #assert_equal @paid_plan, subscription.subscription_plan
    assert_equal 1300, subscription.subscription_plan.rate.cents
  end

  def test_remaining_days
    subscription = Factory.build(:paid_subscription)
    assert_equal (Date.today + 20.days).to_s(:db), subscription.paid_through.to_s(:db)
    assert_equal 20, subscription.remaining_days
  end

  def test_remaining_value
    subscription = Factory.build(:paid_subscription)
    assert_equal Money.new(840), subscription.remaining_value
  end

  ##
  ## Upgrade / Downgrade service credits
  ##

  def test_upgrade_credit
    #TODO: why does this need to be 0?
    Freemium.days_free_trial=0
    subscription = Factory(:paid_subscription, :paid_through => (Date.today + 20), :subscription_plan => Factory(:paid_plan, :rate_cents => 1300))
    new_plan = Factory(:paid_plan, :rate_cents => 3000)

    #assert_equal '2010-04-06', Date.today.to_s(:db)
    #assert_equal '2010-04-26', (Date.today + 20).to_s(:db)
    #assert_equal '2010-04-26', subscription.paid_through.to_s(:db)
    assert_equal 20, subscription.remaining_days
    assert_equal 42, subscription.subscription_plan.daily_rate.cents #$13/month
    assert_equal 840, subscription.remaining_value.cents #20 days * old_plan.daily_rate.cents
    assert_equal 98, new_plan.daily_rate.cents
    assert_equal 8, subscription.remaining_value.cents / new_plan.daily_rate.cents
    expected_paid_through = Date.today + (subscription.remaining_value.cents / new_plan.daily_rate.cents)
    subscription.subscription_plan = new_plan
    subscription.save!

    assert_equal expected_paid_through.to_s(:db), subscription.paid_through.to_s(:db)
  end

  def test_upgrade_no_credit_for_free_trial
    Freemium.days_free_trial=30
    subscription = Factory.build(:free_subscription, :subscription_plan => Factory(:paid_plan), :credit_card => Factory(:credit_card))
    subscription.save!

    assert_equal Date.today + Freemium.days_free_trial, subscription.paid_through
    assert_equal true, subscription.in_trial?

    subscription.subscription_plan = @paid_plan
    subscription.save!

    assert_equal Date.today, subscription.paid_through
    assert_equal false, subscription.in_trial?
  end

  ##
  ## Validations
  ##

  def test_missing_fields
    [:subscription_plan, :subscribable].each do |field|
      subscription = Factory.build(:free_subscription, field => nil)
      subscription.save

      assert subscription.new_record?
      assert subscription.errors.on(field)
    end
  end

  ##
  ## Receiving payment
  ##

  def test_receive_monthly_payment
    subscription = Factory(:paid_subscription)
    paid_through = subscription.paid_through
    subscription.credit(subscription.subscription_plan.rate)
    subscription.save!
    assert_equal (paid_through >> 1).to_s, subscription.paid_through.to_s, "extended by one month"
    assert_not_nil subscription.transactions
  end

  def test_receive_quarterly_payment
    subscription = Factory(:paid_subscription)
    paid_through = subscription.paid_through
    subscription.credit(subscription.subscription_plan.rate * 3)
    subscription.save!
    assert_equal (paid_through >> 3).to_s, subscription.paid_through.to_s, "extended by three months"
  end

  def test_receive_partial_payment
    subscription = Factory(:paid_subscription)
    paid_through = subscription.paid_through
    subscription.credit(subscription.subscription_plan.rate * 0.5)
    subscription.save!
    assert_equal (paid_through + 15).to_s, subscription.paid_through.to_s, "extended by 15 days"
  end

  def test_receiving_payment_sends_invoice
    subscription = Factory(:paid_subscription)
    Freemium.mailer.clear_count
    transaction = create_transaction_for(subscription.subscription_plan.rate, subscription)
    subscription.receive_payment!(transaction)
    assert_equal 1, Freemium.mailer.count
  end

  def test_receiving_payment_saves_transaction_message
    subscription = Factory(:paid_subscription)
    transaction = create_transaction_for(subscription.subscription_plan.rate, subscription)
    subscription.receive_payment!(transaction)
    assert_match /^now paid through/, transaction.reload.message
  end

  def test_receiving_payment_when_sending_invoice_asplodes
    subscription = Factory(:paid_subscription)
    paid_through = subscription.paid_through
    #technically deliver_invoice does not exist (it is a method missing that calls invoice)
    Freemium.mailer.expects(:deliver_invoice).raises(RuntimeError,"Failed")
    Freemium.mailer.expects(:deliver_background_error)
    transaction = create_transaction_for(subscription.subscription_plan.rate, subscription)
    subscription.receive_payment!(transaction)
    subscription = subscription.reload
    assert_equal (paid_through >> 1).to_s, subscription.paid_through.to_s, "extended by one month"
  end

  ##
  ## Requiring Credit Cards ...
  ##

  def test_requiring_credit_card_for_pay_plan
    subscription = Factory.build(:free_subscription, :subscription_plan => Factory(:paid_plan), :credit_card => nil)
    subscription.valid?

    assert subscription.errors.on(:credit_card)
  end

  def test_requiring_credit_card_for_free_plan
    subscription = Factory.build :free_subscription
    subscription.valid?

    assert !subscription.errors.on(:credit_card)
  end

  ##
  ## Expiration
  ##

  def test_instance_expire
    Freemium.expired_plan = @free_plan
    #Freemium.gateway.expects(:unstore).once.returns(nil)
    Freemium.mailer.clear_count
    subscription = Factory(:paid_subscription)
    @paid_plan = subscription.subscription_plan
    assert @paid_plan.paid?
    assert_not_nil old_cc = subscription.credit_card
    subscription.expire!

    assert_equal 1, Freemium.mailer.count, "notice is sent to user"
    assert_equal @free_plan, subscription.subscription_plan, "subscription is downgraded to free"
    #NOTE: others may want different logic here
    assert_not_nil old_cc.billing_key, "billing key is thrown away"
    #assert_nil subscription.reload.billing_key, "billing key is thrown away"

    assert_changed(subscription.subscribable, :expiration, @paid_plan, @free_plan)
  end

  # def test_instance_expire_with_no_expired_plan
  #   Freemium.expired_plan = nil
  #   #Freemium.gateway.expects(:cancel).once.returns(nil)
  #   Freemium.mailer.clear_count
  #   subscription = freemium_subscriptions(:paid_subscription)
  #   assert_equal @paid_plan, subscription.subscription_plan
  #   assert_not_nil old_cc = subscription.credit_card
  #   subscription.expire!
  #
  #   assert_equal 1, Freemium.mailer.count, "notice is sent to user"
  #   assert_equal @paid_plan, subscription.subscription_plan, "subscription was not changed"
  #   assert_nil old_cc.billing_key, "billing key is thrown away"
  #   #assert_nil subscription.reload.billing_key, "billing key is thrown away"
  # end

  def test_class_expire
    Freemium.expired_plan = @free_plan
    subscription = Factory(:paid_subscription)
    subscription.update_attributes(:paid_through => Date.today - 4, :expire_on => Date.today)
    Freemium.mailer.clear_count

    @paid_plan = subscription.subscription_plan
    assert @paid_plan.paid?

    FreemiumSubscription.expire

    assert_equal @free_plan, subscription.reload.subscription_plan
    assert_equal Date.today, subscription.reload.started_on
    assert Freemium.mailer.count > 0

    assert_changed(subscription.subscribable, :expiration, @paid_plan, @free_plan)
  end

  def test_expire_after_grace_sends_warning
    Freemium.mailer.clear_count
    subscription = Factory(:paid_subscription)
    subscription.expire_after_grace!

    assert_equal 1, Freemium.mailer.count
  end

  def test_expire_after_grace
    subscription = Factory(:paid_subscription)
    assert_nil subscription.expire_on
    subscription.paid_through = Date.today - 2
    subscription.expire_after_grace!

    assert_equal Date.today + Freemium.days_grace, subscription.reload.expire_on
  end

  def test_expire_after_grace_with_remaining_paid_period
    subscription = Factory(:paid_subscription)
    subscription.paid_through = Date.today + 1
    subscription.expire_after_grace!

    assert_equal Date.today + 1 + Freemium.days_grace, subscription.reload.expire_on
  end

  def test_grace_and_expiration
    assert_equal 3, Freemium.days_grace, "test assumption"

    subscription = FreemiumSubscription.new(:paid_through => Date.today + 5)
    assert !subscription.in_grace?
    assert !subscription.expired?

    # a subscription that's pastdue but hasn't been flagged to expire yet.
    # this could happen if a billing process skips, in which case the subscriber
    # should still get a full grace period beginning from the failed attempt at billing.
    # even so, the subscription is "in grace", even if the grace period hasn't officially started.
    subscription = FreemiumSubscription.new(:paid_through => Date.today - 5)
    assert subscription.in_grace?
    assert !subscription.expired?

    # expires tomorrow
    subscription = FreemiumSubscription.new(:paid_through => Date.today - 5, :expire_on => Date.today + 1)
    assert_equal 0, subscription.remaining_days_of_grace
    assert subscription.in_grace?
    assert !subscription.expired?

    # expires today
    subscription = FreemiumSubscription.new(:paid_through => Date.today - 5, :expire_on => Date.today)
    assert_equal -1, subscription.remaining_days_of_grace
    assert !subscription.in_grace?
    assert subscription.expired?
  end

  ##
  ## Deleting (possibly from a cascading delete, such as User.find(5).delete)
  ##

  def test_deleting_cancels_in_gateway
    #Freemium.gateway.expects(:unstore).once.returns(nil)
    subscription = Factory(:paid_subscription)
    @paid_plan = subscription.subscription_plan
    subscription.destroy

    assert_changed(subscription.subscribable, :cancellation, @paid_plan, nil)
  end

  ##
  ## The Subscription#credit_card= shortcut
  ##
  def test_adding_a_credit_card
    subscription = Factory.build(:free_subscription, :subscription_plan => Factory(:paid_plan))
    #Freemium.gateway.expects(:store).with(cc, cc.address).returns(response)

    subscription.credit_card = Factory(:credit_card)
    assert_nothing_raised do subscription.save! end
    assert_equal "1", subscription.credit_card.billing_key
  end

  def test_updating_a_credit_card
    subscription = Factory.create(:free_subscription)
    #Freemium.gateway.expects(:update).with(subscription.billing_key, cc, cc.address).returns(response)

    subscription.credit_card = Factory(:credit_card)
    assert_nothing_raised do subscription.save! end
    assert_equal "1", subscription.credit_card.billing_key, "catches any change to the billing key"
  end

  def test_updating_an_expired_credit_card
    #subscription = FreemiumSubscription.find(:first, :conditions => "billing_key IS NOT NULL")
    subscription = Factory.create(:free_subscription)
    #Freemium.gateway.expects(:update).with(subscription.billing_key, cc, cc.address).returns(response)

    subscription.expire_on = Time.now
    assert subscription.save
    assert_not_nil subscription.reload.expire_on

    subscription.credit_card = Factory(:credit_card)
    assert_nothing_raised do subscription.save! end
    assert_nil subscription.expire_on
    assert_nil subscription.reload.expire_on
  end

  def test_failing_to_add_a_credit_card
    subscription = Factory.build(:free_subscription, :subscription_plan => Factory(:paid_plan))
    cc = Factory(:credit_card,:number => ActiveMerchant::Billing::BogusTrustCommerceGateway::BAD_CARD)
    #response = Freemium::Response.new(false)
    #Freemium.gateway.expects(:store).returns(response)

    subscription.credit_card = cc
    assert_raises Freemium::CreditCardStorageError do subscription.save! end
  end

  #
  # assign next plan
  # could go through all of these, but most are in renewable subscription renew!
  #
  def test_assign_next_plan_upgrade
    subscription = Factory(:paid_subscription, :next_subscription_plan => @paid_plan)

    assert_equal @paid_plan, subscription.next_plan

    subscription.assign_next_plan

    assert_equal @paid_plan.id, subscription.subscription_plan_id
    assert_equal @paid_plan, subscription.subscription_plan(true)
  end
  #
  # test non renewable subscriptions, and plans
  #
  def test_next_plan_upgrade
    subscription = Factory(:paid_subscription, :next_subscription_plan => @paid_plan)
    assert subscription.renewable?
    tran = subscription.renew!
    assert_not_nil tran
    assert_equal @paid_plan, subscription.reload.subscription_plan
  end

  def test_autorenew_off
    assert_not_nil @free_plan
    Freemium.expired_plan=@free_plan
    assert_equal @free_plan, Freemium.expired_plan
    subscription = Factory(:paid_subscription, :renewable => false)

    assert_equal Freemium.expired_plan, subscription.next_plan
    tran = subscription.renew!
    assert_nil tran
    assert_equal Freemium.expired_plan, subscription.subscription_plan
  end

  def test_autorenew_on
    Freemium.expired_plan=@free_plan

    subscription = Factory(:paid_subscription, :renewable => true)
    new_plan=subscription.next_plan
    assert new_plan.paid?

    tran = subscription.renew!
    assert_not_nil tran
    assert_equal new_plan, subscription.subscription_plan(true)
  end

  def test_non_renewing_plan_renewable_subscription
    Freemium.expired_plan=@free_plan
    subscription = Factory(:paid_subscription, :subscription_plan => Factory(:free_plan,
        :feature_set_id => 3,
        :duration => "6M",
        :renewable => false),
      :credit_card => Factory(:credit_card))
    assert subscription.renewable?
    assert_equal @free_plan, subscription.next_plan
    tran = subscription.renew!
    assert_nil tran
    assert_equal @free_plan, subscription.subscription_plan(true)
  end

  def test_non_renewing_plan_non_renewable_subscription
    Freemium.expired_plan=@free_plan
    subscription = Factory(:paid_subscription, :subscription_plan => Factory(:free_plan,
        :feature_set_id => 3,
        :duration => "6M",
        :renewable => false),
      :credit_card => Factory(:credit_card),
      :renewable => false)
    assert_equal @free_plan, subscription.next_plan
    tran = subscription.renew!
    assert_nil tran
    assert_equal @free_plan, subscription.subscription_plan(true)
  end

  protected

  #event_link#charge
  #
  def create_transaction_for(amount, subscription)
    FreemiumTransaction.create :amount => amount, :subscription => subscription, :success => true, :purchase=>subscription
      #:person_id => 1
      #:billing_key => 12345
  end

  def assert_changed(subscribable, reason, original_plan, new_plan)
    changes = FreemiumSubscriptionChange.find(:all, :conditions => ["subscribable_id = ? AND subscribable_type = ?", subscribable.id, subscribable.class.to_s]).last
    assert_not_nil changes
    assert_equal reason.to_s, changes.reason
    assert_equal original_plan, changes.original_subscription_plan
    assert_equal new_plan, changes.new_subscription_plan
    assert_equal (original_plan ? original_plan.rate.cents : 0), changes.original_rate_cents
    assert_equal (new_plan ? new_plan.rate.cents : 0), changes.new_rate_cents
  end
end