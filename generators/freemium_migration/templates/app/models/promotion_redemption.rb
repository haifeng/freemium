# == Schema Information
# Schema version: 201001225114910
#
# Table name: promotion_redemptions
#
#  id              :integer(4)    not null, primary key
#  subscription_id :integer(4)    not null
#  coupon_id       :integer(4)    not null
#  redeemed_on     :date          not null
#  expired_on      :date          
#

class PromotionRedemption < ActiveRecord::Base
  belongs_to :subscription, :class_name => "FreemiumSubscription", :foreign_key => :subscription_id
  belongs_to :coupon, :class_name => "Promotion", :foreign_key => :coupon_id
  include Freemium::CouponRedemption

  #we have a list of coupons - but need redemptions to be able to properly choose 
  def self.redemptions_for_coupons(subscription, coupons, date=Date.today)
    coupons.collect do |coupon|
      PromotionRedemption.new( :subscription => subscription, :coupon => coupon, :redeemed_on => date)
    end
  end
end
