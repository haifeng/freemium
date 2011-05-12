require File.dirname(__FILE__) + '/../test_helper'

class PromotionRedemptionTest < ActiveSupport::TestCase
  def setup
    @subscription = Factory(:paid_subscription)
    @original_price = @subscription.rate
    @original_plan  = @subscription.subscription_plan
    @coupon = Promotion.create(:name => '30off', :description => "30% off", :discount_percentage => 30, :promotion_code => "30OFF", :duration => '3M')
  end
  
  def test_apply
    @subscription.paid_through = Date.today + 30
    @original_remaining_value = @subscription.remaining_value
    @original_daily_rate = @subscription.daily_rate
    @subscription.coupon_key = nil
    
    assert @subscription.coupon_redemptions.create(:coupon => @coupon)
    assert_equal @coupon.discounted_rate(@original_plan).rate.cents, @subscription.rate.cents
    assert_equal @coupon.discount(@original_daily_rate).cents, @subscription.daily_rate.cents
    assert_equal (@coupon.discount(@original_daily_rate) * @subscription.remaining_days).cents, @subscription.remaining_value.cents
  end  

  def test_discount_rate_monthly
    @plan=FreemiumSubscriptionPlan.new(:duration => '1M', :rate_cents => 2000)
    #@coupon = 30%
    new_rate=@coupon.discounted_rate(@plan)
    assert_equal 1400, new_rate.monthly_rate.cents
    assert_equal '1M', new_rate.duration
  end

  def test_discount_rate_2monthly
    @plan=FreemiumSubscriptionPlan.new(:duration => '2M', :rate_cents => 4000)
    #@coupon = 30%
    new_rate=@coupon.discounted_rate(@plan)
    assert_equal 1400, new_rate.monthly_rate.cents
    assert_equal '2M', new_rate.duration
  end

  def test_discount_rate_3monthly_rounded
    @plan=FreemiumSubscriptionPlan.new(:duration => '3M', :rate_cents => 3100)
    #@coupon = 30%
    new_rate=@coupon.discounted_rate(@plan)
    new_rate.round!
    assert_equal 725, new_rate.monthly_rate.cents
    assert_equal 2175, new_rate.rate.cents
    assert_equal '3M', new_rate.duration
  end


  def test_apply_using_coupon_accessor
    @subscription = Factory.build(:paid_subscription, :coupon => @coupon, :credit_card => Factory(:credit_card))
    @subscription.save!
    
    assert_not_nil @subscription.coupon
    assert_not_nil @subscription.coupon_redemptions.first.coupon
    assert_not_nil @subscription.coupon_redemptions.first.subscription
    assert !@subscription.coupon_redemptions.empty?
    assert_equal @coupon.discounted_rate(@original_plan).rate.cents, @subscription.rate.cents
  end
  
  def test_apply_using_coupon_key_accessor
    @subscription = Factory.build(:paid_subscription, :coupon_key => @coupon.promotion_code, :credit_card => Factory(:credit_card))
    @subscription.save!
    
    assert_not_nil @subscription.coupon
    assert_not_nil @subscription.coupon_redemptions.first.coupon
    assert_not_nil @subscription.coupon_redemptions.first.subscription
    assert !@subscription.coupon_redemptions.empty?
    assert_equal @coupon.discounted_rate(@subscription.subscription_plan).rate.cents, @subscription.rate.cents
  end

  def test_apply_multiple
    @coupon_1 = Promotion.new(:name => '10off', :description => "10% off", :discount_percentage => 10)
    assert @subscription.coupon_redemptions.create(:coupon => @coupon_1)
    
    @coupon_2 = Promotion.new(:name => '30off', :description => "30% off", :discount_percentage => 30)
    assert @subscription.coupon_redemptions.create(:coupon => @coupon_2)
    
    @coupon_3 = Promotion.new(:name => '20off', :description => "20% off", :discount_percentage => 20)
    assert @subscription.coupon_redemptions.create(:coupon => @coupon_3)

    # Should use the highest discounted coupon
    assert_equal @coupon_2.discounted_rate(@original_plan).rate.cents, @subscription.rate.cents
  end  
  
  def test_destroy
    assert @subscription.coupon_redemptions.create(:coupon => @coupon)
    assert_equal @coupon.discounted_rate(@original_plan).rate.cents, @subscription.rate.cents
    
    @coupon.destroy
    @subscription.reload
    
    assert @subscription.coupon_redemptions.empty?
    assert_equal @original_price.cents, @subscription.rate.cents
  end 
  
  def test_coupon_duration
    assert @subscription.coupon_redemptions.create(:coupon => @coupon)
    assert_equal @coupon.discounted_rate(@original_plan).rate.cents, @subscription.rate.cents
    assert_equal @coupon.duration_days, 3.months #mine
    
    assert_equal @coupon.discounted_rate(@original_plan).rate.cents, @subscription.rate({:date => (Date.today + 3.months - 1)}).cents
    assert_equal @original_price.cents, @subscription.rate({:date => (Date.today + 3.months + 1)}).cents

    Timecop.travel(Time.now + 3.months - 1.day) do
      assert_equal @coupon.discounted_rate(@original_plan).rate.cents, @subscription.rate.cents
    end
    
    #expecting the coupon to no longer apply
    Timecop.travel(Time.now + 3.months) do
      assert_equal @original_price.cents, @subscription.rate.cents
      #assert_equal @coupon.discounted_rate(@original_plan).rate.cents, @subscription.rate.cents
    end

    Timecop.travel(Time.now + 3.months + 1.day) do
      assert_equal @original_price.cents, @subscription.rate.cents
    end
  end  
  
  def test_apply_complimentary
    @coupon.discount_percentage = 100
    
    @subscription = Factory.build(:paid_subscription, :coupon => @coupon, :credit_card => Factory(:credit_card), :subscription_plan => Factory(:paid_plan))
    
    assert @subscription.save
    assert_not_nil @subscription.coupon
    assert_equal 0, @subscription.rate.cents
    assert !@subscription.paid?
  end  
  
  ##
  ## Plan-specific coupons
  ##
  
  def test_apply_premium_only_coupon_on_new
    set_coupon_to_premium_only
    
    @subscription = Factory.build(:paid_subscription, :coupon => @coupon, :credit_card => Factory(:credit_card), :subscription_plan => @coupon.subscription_plans.first)
    
    assert @subscription.save
    assert_not_nil @subscription.coupon
  end

  def test_apply_premium_only_coupon_on_existing
    set_coupon_to_premium_only

    @subscription.coupon = @coupon    
    @subscription.subscription_plan = @coupon.subscription_plans.first
    
    assert @subscription.save
    assert_not_nil @subscription.coupon
  end  
  
  def test_invalid_apply_premium_only_coupon_on_new
    set_coupon_to_premium_only
    
    @subscription = Factory.build(:paid_subscription, :coupon => @coupon, :credit_card => Factory(:credit_card), :subscription_plan => Factory(:paid_plan))
    
    assert !@subscription.save
    assert !@subscription.errors.on(:coupon_redemptions).empty?
  end  
  
  def test_invalid_apply_premium_only_coupon_on_existing
    set_coupon_to_premium_only
    
    assert_equal false, @coupon.subscription_plans.include?(@subscription.subscription_plan)
    assert !@subscription.errors.on(:coupon_redemptions).try(:empty?)
    @subscription.coupon = @coupon
    
    assert_equal false, @subscription.save
    assert_equal false, @subscription.errors.on(:coupon_redemptions).empty?
  end
  
  ##
  ## applying coupons
  ##
  
  def test_apply_coupon
    @subscription.coupon = @coupon
    assert @subscription.valid?
    assert_not_nil @subscription.coupon
  end
  
  def test_apply_invalid_key
    assert_not_nil @coupon.promotion_code
    @subscription.coupon_key = @coupon.promotion_code + "xxxxx"

    assert_equal false, @subscription.valid?
    assert_nil @subscription.coupon
    assert_equal false, @subscription.errors.on(:coupon).empty?
  end  

  def test_apply_invalid_coupon
    set_coupon_to_premium_only
    
    assert_equal false, @coupon.subscription_plans.include?(@subscription.subscription_plan)
    
    @subscription.coupon = @coupon
    assert !@subscription.valid?  
    assert !@subscription.errors.on(:coupon_redemptions).empty?
  end
  
  protected
  
  def set_coupon_to_premium_only
    @coupon.subscription_plans << Factory(:paid_plan)
    @coupon.save!
  end


  public
  
  ##
  ## Validation Tests
  ##
  
  def test_invalid_no_coupon
    s = PromotionRedemption.new(:subscription => @subscription)
    assert !s.save
    assert !s.errors.on(:coupon).empty?
  end  

  # note: rules stating whether a coupon can be applied are becoming more lax
  # a coupon may extend the length of a free plan.
  #
  # def test_invalid_cannot_apply_to_unpaid_subscription
  #   assert !freemium_subscriptions(:free_subscription).paid?
  #   s = PromotionRedemption.new(:subscription => freemium_subscriptions(:free_subscription), :coupon => @coupon)
  #   assert !s.save
  #   assert !s.errors.on(:subscription).empty?
  # end
  
  def test_invalid_cannot_apply_twice
    s = PromotionRedemption.new(:subscription => @subscription, :coupon => @coupon)
    assert s.save
    
    s = PromotionRedemption.new(:subscription => @subscription, :coupon => @coupon)
    assert_equal false, s.save
    assert !s.errors.on(:coupon_id).empty?    
  end
  
  def test_invalid_redemption_expired
    @coupon.redemption_expiration = Date.today-1
    @coupon.save!
    
    s = PromotionRedemption.new(:subscription => @subscription, :coupon => @coupon)
    assert_equal false, s.save
    assert !s.errors.on(:coupon).empty?    
  end
  
  def test_invalid_too_many_redemptions
    @coupon.redemption_limit = 1
    @coupon.save!
    
    s = PromotionRedemption.new(:subscription => @subscription, :coupon => @coupon)
    s.save!
    
    #this creates one with a different subscription
    s = PromotionRedemption.new(:subscription => Factory(:paid_subscription), :coupon => @coupon)
    assert_equal false, s.save
    assert !s.errors.on(:coupon).empty?    
  end
end