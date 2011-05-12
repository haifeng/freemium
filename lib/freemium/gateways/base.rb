module Freemium
  module Gateways
    class Base #:nodoc:
      # cancels the subscription identified by the given billing key.
      # this might mean removing it from the remote system, or halting the remote
      # recurring billing.
      #
      # should return a Freemium::Response

      #ActiveRecord: delete/unstore(billing_id, options)
      def cancel(billing_key)
        raise MethodNotImplemented
      end

      # stores a credit card with the gateway.
      # should return a Freemium::Response

      #ActiveRecord: store (cc, options)
      def store(credit_card, address = nil)
        raise MethodNotImplemented
      end

      # updates a credit card in the gateway.
      # should return a Freemium::Response

      #ActiveRecord: update(billing_id, cc, options) - or store
      def update(billing_key, credit_card = nil, address = nil)
        raise MethodNotImplemented
      end

      # validates a credit card with the gateway.
      # should return a Freemium::Response

      #NOT IMPLIMENTED? / AUTH?
      def validate(credit_card, address = nil)
        raise MethodNotImplemented
      end

      ##
      ## Only needed to support Freemium.billing_handler = :gateway
      ##

      # only needed to support an ARB module. otherwise, the manual billing process will
      # take care of processing transaction information as it happens.
      #
      # concrete classes need to support these options:
      #   :billing_key : - only retrieve transactions for this specific billing key
      #   :after :       - only retrieve transactions after this datetime (non-inclusive)
      #   :before :      - only retrieve transactions before this datetime (non-inclusive)
      #
      # return value should be a collection of Freemium::Transaction objects.

      def transactions(options = {})
        raise MethodNotImplemented
      end

      ##
      ## Only needed to support Freemium.billing_handler = :manual
      ##

      # charges money against the given billing key.
      # should return a Freemium::Transaction

      #ActiveMerchant: purchase
      def charge(billing_key, amount)
        raise MethodNotImplemented
      end
    end
  end
end
