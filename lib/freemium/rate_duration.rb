module Freemium
  class RateDuration
    include Freemium::Rates
    include Freemium::DurationString

    #rate in Money
    attr_accessor :rate
    #rate in cents
    #attr_accessor :rate_cents
    #string e.g. 1M
    attr_accessor :duration

    def initialize(args)
      if args[:rate]
        @rate=args[:rate]
      elsif args[:rate_cents]
        @rate=Money.new(args[:rate_cents])
      end
      @duration=args[:duration]
    end

    def ==(other)
      @rate == other.rate && @duration == other.duration
    end
  end
end