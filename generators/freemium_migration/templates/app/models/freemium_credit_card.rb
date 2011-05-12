# == Schema Information
# Schema version: 201001225114910
#
# Table name: freemium_credit_cards
#
#  id              :integer(4)    not null, primary key
#  display_number  :string(255)   not null
#  card_type       :string(255)   not null
#  expiration_date :datetime      not null
#  zip_code        :string(255)   
#  billing_key     :string(255)   
#  address1        :string(255)   
#  address2        :string(255)   
#  city            :string(255)   
#  state           :string(255)   
#  name            :string(255)   
#

class FreemiumCreditCard < ActiveRecord::Base
  CARD_TYPES = [{:value => 'visa', :label => 'Visa'}, {:value => 'master', :label => "Mastercard"}, 
#    {:value => 'american_express', :label => 'American Express'},
    {:value => 'discover', :label => 'Discover'}
  ] 
  has_one :subscription, :class_name => "FreemiumSubscription", :foreign_key => 'credit_card_id'
  include Freemium::CreditCard
end
