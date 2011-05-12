# == Schema Information
# Schema version: 201001225114910
#
# Table name: freemium_transactions
#
#  id                     :integer(4)    not null, primary key
#  subscription_id        :integer(4)    not null
#  success                :boolean(1)    
#  amount_cents           :integer(4)    not null
#  message                :string(255)   
#  created_at             :datetime      not null
#  updated_at             :datetime      
#  gateway_transaction_id :string(255)   
#  purchase_type          :string(255)   not null
#  purchase_id            :integer(4)    not null
#

class FreemiumTransaction < ActiveRecord::Base
  named_scope :by_creation, :order => "freemium_transactions.id"
  belongs_to :subscription, :class_name => "FreemiumSubscription"
  belongs_to :purchase, :polymorphic => true

  composed_of :amount, :class_name => 'Money', :mapping => [ %w(amount_cents cents) ], :allow_nil => true

  include Freemium::Transaction
  
end
