module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # Bogus Gateway
    class BogusTrustCommerceGateway < Gateway
      #took these from TrustComerce documentation for cards
      BILLING_ID_GOOD='1'
      GOOD_CARD ='4111111111111111' #valid visa
      GOOD_CVV1 ='123'
      GOOD_CARD2='5411111111111115' #valid mastercard
      GOOD_CVV2 ='777'
      BILLING_ID_BAD='2'
      BAD_CARD  ='4012345678909'    #declined
      BAD_CARD2 ='5555444433332226'    #call in
      #NOTE: this card number in trustee guide is a card error
      # we keep getting card errors where they auth / save fine - but charge makes them fail
      # so store / auth work, purchase fails
      BILLING_ID_ODD='3'
      ODD_CARD1 ='4444111144441111'
      ODD_CVV1  = GOOD_CVV1

      AUTHORIZATION = '53433'
      
      SUCCESS_MESSAGE = "Bogus Gateway: Forced success"
      FAILURE_MESSAGE = "Bogus Gateway: Forced failure"
      ERROR_MESSAGE = "Bogus Gateway: Use CreditCard number 1 for success, 2 for exception and anything else for error"
      CREDIT_ERROR_MESSAGE = "Bogus Gateway: Use trans_id 1 for success, 2 for exception and anything else for error"
      UNSTORE_ERROR_MESSAGE = "Bogus Gateway: Use billing_id 1 for success, 2 for exception and anything else for error"
      CAPTURE_ERROR_MESSAGE = "Bogus Gateway: Use authorization number 1 for exception, 2 for error and anything else for success"
      VOID_ERROR_MESSAGE = "Bogus Gateway: Use authorization number 1 for exception, 2 for error and anything else for success"
      
      self.supported_countries = ['US']
      self.supported_cardtypes = [:bogus]
      self.homepage_url = 'http://example.com'
      self.display_name = 'Bogus'
      
      def authorize(money, creditcard, options = {})
        number = creditcard.is_a?(String) ? creditcard : creditcard.number
        case number
        when BILLING_ID_GOOD, BILLING_ID_ODD, GOOD_CARD, GOOD_CARD2, ODD_CARD1
          #TODO: research
          respond(true,'P',{:authorized_amount => money.to_s}, {:authorization => AUTHORIZATION})
        when BILLING_ID_BAD, BAD_CARD, BAD_CARD2
          #TODO: research
          respond(false)
        else
          raise Error, ERROR_MESSAGE
        end      
      end
  
      def purchase(money, creditcard, options = {})
        number = creditcard.is_a?(String) ? creditcard : creditcard.number
        case number
        when BILLING_ID_GOOD, GOOD_CARD, GOOD_CARD2
          #TODO: does paid_amount come back for trust commerce? (thinking not) Other vendors seem to return it
          respond(true,nil,{:paid_amount => money.to_s, :transid => '3'})
        when BILLING_ID_BAD, BILLING_ID_ODD, BAD_CARD, BAD_CARD2, ODD_CARD1
          #TODO: does paid_amount come back for trust commerce? (thinking not)
          respond(false)
        else
          raise Error, ERROR_MESSAGE
        end
      end
 
      def credit(money, trans_id, options = {})
        case trans_id
        when '1'
          raise Error, CREDIT_ERROR_MESSAGE
        when '2'
          #TODO: research
          respond(false)
        else
          #TODO: research
          respond(true)
        end
      end
 
      def capture(money, trans_id, options = {})
        case trans_id
        when '1'
          raise Error, CAPTURE_ERROR_MESSAGE
        when '2'
          #TODO: research
          respond(false)
        else
          #TODO: research
          respond(true, {:paid_amount => money.to_s})
        end
      end

      def void(ident, options = {})
        case ident
        when '1'
          raise Error, VOID_ERROR_MESSAGE
        when '2'
          #haven't researched this one
          respond(false,nil,{:authorization => ident})
        else
          #haven't researched this one
          respond(true,nil,{:authorization => ident})
        end
      end
      
      def store(creditcard, options = {})
        cvv=creditcard.verification_value
        case creditcard.number
        when '1'
          respond(true,cvv_check(nil,GOOD_CVV1),{:billingid => BILLING_ID_GOOD},{:authorization => AUTHORIZATION})
        when GOOD_CARD
          respond(true,cvv_check(cvv,GOOD_CVV1),{:billingid => BILLING_ID_GOOD},{:authorization => AUTHORIZATION})
        when GOOD_CARD2
          respond(true,cvv_check(cvv,GOOD_CVV2),{:billingid => BILLING_ID_GOOD},{:authorization => AUTHORIZATION})
        when ODD_CARD1
          respond(true,cvv_check(cvv,GOOD_CVV1),{:billingid => BILLING_ID_ODD},{:authorization => AUTHORIZATION})
        when '2', BAD_CARD, BAD_CARD2
          respond(false,nil,{:billingid => nil})
        else
          raise Error, ERROR_MESSAGE + "was #{credit_card.number}"
        end              
      end
      
      def unstore(identification, options = {})
        case identification
        when '1'
          respond(true)
        when '2'
          respond(false)
        else
          raise Error, UNSTORE_ERROR_MESSAGE
        end
      end

      private
      def cvv_check(my_cvv,good_cvv)
        case my_cvv
        when nil
          'P' #non passed
        when good_cvv
          'M' #match
        else
          'N' #non-match (aka - bad)
        end
      end

      def respond(good_cc,cvv_result=nil,params={},options={})
        params||={}
        options||={}
        options[:test] = true
        params[:error]=FAILURE_MESSAGE if !good_cc
        if cvv_result
          options[:cvv_result]=cvv_result
        end
        Response.new(good_cc, good_cc ? SUCCESS_MESSAGE : FAILURE_MESSAGE, params, options)
      end
    end
  end
end
