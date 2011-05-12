class CreateFreemiumModels < ActiveRecord::Migration
  def self.up    
    create_table :freemium_subscription_plans, :force => true do |t|
      t.column :name, :string, :null => false
      t.column :redemption_key, :string, :null => false
      t.column :rate_cents, :integer, :null => false
      t.column :feature_set_id, :string, :null => false
      t.column :next_subscription_plan_id, :integer
      t.column :renewable, :boolean, :default => true, :null => false
    end

    create_table :freemium_subscriptions, :force => true do |t|
      t.column :subscribable_id, :integer, :null => false
      t.column :subscribable_type, :string, :null => false
      t.column :credit_card_id, :integer, :null => true
      t.column :subscription_plan_id, :integer, :null => false
      t.column :paid_through, :date, :null => true
      t.column :expire_on, :date, :null => true
      t.column :started_on, :date, :null => true
      t.column :last_transaction_at, :datetime, :null => true
      t.column :in_trial, :boolean, :null => false, :default => false
      t.column :next_subscription_plan_id, :integer
    end

    create_table :freemium_credit_cards, :force => true do |t|
      t.column :display_number, :string, :null => false
      t.column :card_type, :string, :null => false
      t.column :expiration_date, :timestamp, :null => false
      t.column :zip_code, :string, :null => true
    t.column :billing_key, :string, :null => true
    end  

    create_table :promotions, :force => true do |t|  
      t.column :description, :string, :null => false
      t.column :discount_percentage, :integer, :null => false 
      t.column :redemption_key, :string, :null => true
      t.column :redemption_limit, :integer, :null => true 
      t.column :redemption_expiration, :date, :null => true
      t.column :duration, :string, :null => true, :limit => 5
    end

    create_table :freemium_coupons_subscription_plans, :id => false, :force => true do |t|
      t.column :coupon_id, :integer, :null => false
      t.column :subscription_plan_id, :integer, :null => false
    end  

    create_table :promotion_redemptions, :force => true do |t|
      t.column :subscription_id, :integer, :null => false
      t.column :coupon_id, :integer, :null => false 
      t.column :redeemed_on, :date, :null => false 
      t.column :expired_on, :date, :null => true
    end   
    
    create_table :freemium_transactions, :force => true do |t|  
      t.column :subscription_id, :integer, :null => false
      t.column :success, :boolean, :null => false 
      t.column :amount_cents, :integer, :null => false
      t.column :message, :string, :null => true
      t.column :created_at, :timestamp, :null => false
      t.column :gateway_transaction_id, :string, :null => true
    end  

    create_table :freemium_subscription_changes, :force => true do |t|  
      t.column :subscribable_id, :integer, :null => false
      t.column :subscribable_type, :string, :null => false
      t.column :original_subscription_plan_id, :integer, :null => true
      t.column :new_subscription_plan_id, :integer, :null => true
      t.column :original_rate_cents, :integer, :null => true
      t.column :new_rate_cents, :integer, :null => true
      t.column :reason, :string, :null => false 
      t.column :created_at, :timestamp, :null => false
    end    

    # for applying transactions from automated recurring billing
    add_index :freemium_subscription_plans, :redemption_key
    
    # for polymorphic association queries
    #add_index :freemium_subscriptions, :subscribable_id
    #add_index :freemium_subscriptions, :subscribable_type
    add_index :freemium_subscriptions, [:subscribable_id, :subscribable_type], :name => :index_subscriptions_on_subscribable
    
    # for finding due, pastdue, and expiring subscriptions
    add_index :freemium_subscriptions, :paid_through
    add_index :freemium_subscriptions, :expire_on

    # for applying transactions from automated recurring billing
    add_index :freemium_subscriptions, :billing_key    
    
    # the autogenerated index names are too long :(
    add_index :freemium_coupons_subscription_plans, :coupon_id
    add_index :freemium_coupons_subscription_plans, :subscription_plan_id, :name => :index_coupon_sub_on_plan_id
    
    add_index :freemium_coupon_redemptions, :subscription_id 
    
    add_index :freemium_transactions, :subscription_id   
    
    add_index :freemium_subscription_changes, :reason
    add_index :freemium_subscription_changes, [:subscribable_id, :subscribable_type], :name => :index_subscription_changes_on_subscribable
  end

  def self.down
    drop_table :freemium_subscription_plans
    drop_table :freemium_subscriptions
    drop_table :freemium_credit_cards
    drop_table :promotions
    drop_table :freemium_coupons_subscription_plans
    drop_table :promotion_redemptions
    drop_table :freemium_transactions
    drop_table :freemium_subscription_changes
  end
end
