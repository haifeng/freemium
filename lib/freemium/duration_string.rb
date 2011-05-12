module Freemium
  module DurationString
    DURATION_VALUES=[['5 Days','5D'], ['1 Week','1W'], ['1 Month','1M'],['3 Months', '3M'],['6 Months','6M'],['9 Months','9M'],['1 Year','1Y']]
#    DURATION_TEXT=DURATION_VALUES.inject({}) { |a,v| a[v[1]]=v[0]; a}
    YEARLY='1Y'
    MONTHLY='1M'

    DURATION_CONSTANTS={'D' => 'days', 'W' => 'weeks', 'M' => 'months', 'Y' => 'years'}

    def self.included(base)
#      base.extend         ClassMethods
      base.send :include, InstanceMethods
    end

    # module ClassMethods
    # end

    module InstanceMethods
      def duration_parts
        units=Freemium::DurationString::DURATION_CONSTANTS[self.duration[-1..-1]]
        number=self.duration[0..-2].to_i
        [number,units]
      end

      def duration_text
        return if duration.nil?
        number,units=duration_parts

        return unless number.present? && units.present?
        "#{number} #{(number==1 ? units.singularize : units)}"
      end

      #return an encoded duration (e.g. 5.days)
      def duration_days
        return nil if self.duration.blank?
        number,units=duration_parts
        return unless number.present? && units.present?

        if units=='years'
          number=12*number
          units='months'
        end
        number.send(units)
      end
    
      def duration_in_months
        days=duration_days
        days ? days / 1.month : nil
      end

      def duration_in_months=(value)
        self.duration="#{value}M"
      end

      def yearly?
        return false if self.duration.blank?
        duration_parts[1]=="years"
      end

      def daily?
        return false if self.duration.blank?
        duration_parts[1]=="days"
      end

      # a plan can either go forever, or it can have a term limit
      # true means this expires and needs to be renewed - e.g.: beta, $20/month
      # false means that it never expires - e.g.: free, alpha

      #used with plans - does it expire (does it have a duration)
      #in manual_billing - was split away from paid
      def expires?
        self.duration.present?
      end
    end
  end
end
