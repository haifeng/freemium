module Freemium

  #used by subscription and subscription plan to
  #used to determine remaining value - when switching between plans before fully paid

  #Assumes also has DurationString

  module Rates
    
    #subscription takes optional parameters into rate and daily_rate.
    #*args allows us to pass along the parameters

    # returns the daily cost of this plan.
    def daily_rate(*args)
      if paid?
        if daily?
          rate(*args)
        else
          yearly_rate(*args) / 365
        end
      else
        nil
      end
    end

    # returns the yearly cost of this plan.
    def yearly_rate(*args)
      if paid?
        if yearly?
          rate(*args) / duration_parts[0] #number of years
        else
          rate(*args) / duration_in_months * 12
        end
      else
        nil
      end
    end

    # returns the monthly cost of this plan.
    # NOTE: does not work with days
    # TODO: use parts and calculate for each case from there
    def monthly_rate(*args)
      if duration.present? && paid?
        rate(*args) / duration_in_months
      else
        rate(*args)
      end
    end

    #this is a paid plan (opposite of free? )
    def paid?
      rate.present? && rate.cents > 0
    end

    # costs nothing
    def free?
      ! paid?
      #self.rate_cents == 0 || self.rate_cents.nil?
    end
    
    #round so the monthly rate is a multiple of a quarter
    def round!
      new_monthly_rate = (monthly_rate.cents / 25.0).round * 25
      #get back to full term
      new_rate = duration_in_months * new_monthly_rate
      self.rate = Money.new(new_rate)
    end

    def rate_duration
      RateDuration.new(:rate => rate, :duration => duration)
    end
  end
end