require File.dirname(__FILE__) + '/../test_helper'

class DurationTest < ActiveSupport::TestCase
  # def test_monthly_rate_from_days
  #   ds = Freemium::RateDuration.new(:rate_cents => 100, :duration => "5D")
  #   assert_equal (1/6.0), ds.duration_in_months
  # end

  def test_monthly_rate_from_months
    ds = Freemium::RateDuration.new(:rate_cents => 100, :duration => "5M")
    assert_equal 5, ds.duration_in_months
  end

  def test_monthly_rate_from_years
    ds = Freemium::RateDuration.new(:rate_cents => 100, :duration => "1Y")
    assert_equal 12, ds.duration_in_months
  end

  # def test_convert
  #   ds = Freemium::RateDuration.new(:rate_cents => 100, :duration => "5D")
  #   assert_equal 600, ds.monthly_rate.cents
  # end
end
