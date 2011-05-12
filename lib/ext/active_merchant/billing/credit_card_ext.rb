ActiveMerchant::Billing::CreditCard.class_eval do
      def card_type
        @type
      end

      def card_type=(value)
        @type=value
      end
end
