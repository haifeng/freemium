require File.dirname(__FILE__) + '/../test_helper'

class CreditCardTest < ActiveSupport::TestCase
  def setup
    @subscription = Factory(:paid_subscription)
    @credit_card = Factory.build(:credit_card)
  end
  
  def test_create
    @subscription.credit_card = @credit_card

    assert @subscription.save, @subscription.errors.full_messages
    @subscription = FreemiumSubscription.find(@subscription.id)
    assert_not_nil @subscription.credit_card.billing_key
    assert_not_nil @subscription.credit_card.display_number
    assert_not_nil @subscription.credit_card.card_type
    assert_not_nil @subscription.credit_card.expiration_date
  end

  # TODO: add 'validate' to active merchant interface
  # def test_create_with_billing_validation_failure
  #   @credit_card.number="2"
  #   @credit_card.card_type="bogus"
  #   response = Freemium::Response.new(false, 'responsetext' => 'FAILED')
  #   response.message = 'FAILED'
  # 
  #   Freemium.gateway.stubs(:validate).returns(response)
  # 
  #   @subscription.credit_card = @credit_card
  # 
  #   assert !@subscription.save
  #   assert_match /FAILED/, @subscription.errors.on_base
  # end

  def test_update
    @subscription.credit_card = @credit_card

    assert @subscription.save
    @subscription = FreemiumSubscription.find(@subscription.id)
    assert_not_nil @subscription.credit_card.billing_key

    original_key = @subscription.credit_card.billing_key
    original_expiration = @subscription.credit_card.expiration_date

    @subscription.reload

    #NOTE: we are updating the credit card, not replacing it
    cc2=Factory.attributes_for(:credit_card,:zip_code => 95060, :number => ActiveMerchant::Billing::BogusTrustCommerceGateway::GOOD_CARD2, :card_type => 'master', :year => 2020)

    @subscription.credit_card.populate_from_cc(cc2)
    assert @subscription.credit_card.valid?, @subscription.credit_card.errors.full_messages.join(". ")
    assert @subscription.save, @subscription.errors.full_messages.join(". ")

    @subscription = FreemiumSubscription.find(@subscription.id)
    assert_equal original_key, @subscription.credit_card.billing_key
    assert_operator @subscription.credit_card.expiration_date, :>, original_expiration
    assert_equal "95060", @subscription.credit_card.reload.zip_code
  end
    
  ##
  ## Test Validations
  ##

  def test_name_no_first_last
    #@credit_card.first_name=nil
    #@credit_card.last_name=nil
    @credit_card.name=nil
    assert_equal false, @credit_card.valid?, 'credit card not valid without first/last name'
    @credit_card.name='santa claus'
    assert @credit_card.valid?, 'credit card valid with combo first_last_name field'
  end

  def test_create_invalid_number
    @credit_card = Factory(:credit_card,:number => 'foo')
    assert_equal false, @credit_card.valid?, 'credit card with bad number is not valid'
    assert_equal false, @credit_card.save
  end

  def test_create_expired_card
    @credit_card = Factory(:credit_card,:year => 2001)
    assert_equal false, @credit_card.valid?, 'expired credit card is not valid'
    assert_equal false, @credit_card.save
  end
  
  def test_changed_on_new
    # We're overriding AR#changed? to include instance vars that aren't persisted to see if a new card is being set
    assert @credit_card.changed?, "New card is changed"
  end  
  
  def test_changed_after_reload
    @credit_card.save!
    @credit_card = FreemiumCreditCard.find(@credit_card.id)
    assert_equal false, @credit_card.reload.changed?, "Saved card is NOT changed"
  end       
  
  #assert that someone else's credit card did not change?
  # def test_changed_existing
  #   assert !freemium_credit_cards(:bobs_credit_card).changed?
  # end  
    
  def test_changed_after_update
    @credit_card.save
    @credit_card.reload #fresh from disk
    @credit_card.number="foo"
    assert @credit_card.changed?
  end
  
  def test_validate_on_new
    assert @credit_card.valid?, "New card is valid"
  end
  
  def test_validate_existing_unchanged
    # existing cards on file are valid ...
    @credit_card.save
    @credit_card.reload #fresh from disk
    assert_equal false, @credit_card.changed?, "Existing card has not changed"
    assert @credit_card.valid?, "Existing card is valid"
  end
    
  def test_validate_existing_changed_number
    # ... unless theres an attempt to update them
    @credit_card.save
    @credit_card.reload #fresh from disk
    @credit_card.populate_from_cc(:number => "foo")
    assert @credit_card.changed?
    assert_equal false, @credit_card.valid?, "Partially changed existing card is not valid"
  end
  
  # def test_validate_existing_changed_card_type
  #   # ... unless theres an attempt to update them
  #   cc=freemium_credit_cards(:bobs_credit_card)
  #   cc.populate_from_cc(:card_type => "visa")
  #   assert cc.changed?
  #   assert_equal false, cc.valid?, "Partially changed existing card is not valid"
  # end  
  
  #test storing remote vs storing locally

  #update basic data - want to store
  def test_will_store_remote
    assert @credit_card.should_store_offsite?
  end

  #already stored offsite - shouldn't want to store again
  def test_will_not_store_twice
    @credit_card.save
    assert @credit_card.stored_offsite?, 'should state it is stored offsite after save'
    assert_equal false, @credit_card.should_store_offsite?, 'should not want to store it offsite after save'
  end

  #just loaded data - shouldn't want to store offline
  def test_will_not_store_after_reload
    @credit_card.save
    @credit_card.reload
    assert @credit_card.stored_offsite?, 'should know a reloaded credit card is stored offsite'
    assert_equal false, @credit_card.changed?, 'should not be marked as changed'
    assert_equal false, @credit_card.should_store_offsite?, 'should not want to store it offsite after reloading'
  end

  #set data only (and remote billing_key) - shouldn't want to store remotely
  def test_will_not_store_trustee_loaded_card
    @credit_card = Factory.build(:credit_card,
      :number     => '1111',
      :card_type  => 'visa',
      :expiration => '1112',
      :zip_code   => '02142'
    )
    @credit_card.billing_key = '1'
    @credit_card.trustee = true
    assert_equal false, @credit_card.should_store_offsite?
  end

  #updated expiration date, should want to store remotely again
  def test_will_store_updated_credit_card_number
    @credit_card.save
    @credit_card.reload
    @credit_card.expiration='1115'
    assert @credit_card.changed?, 'should be marked as changed'
    assert @credit_card.should_store_offsite?, 'should want to store changed credit cards offsite'
  end
end