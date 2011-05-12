module Freemium
  class CreditCardStorageError < RuntimeError
    attr_accessor :response
    def initialize(field,message,response)
      super(message)
      @field=field||:number
      @response=response
    end
    def inspect
      @response.inspect
    end
    #TODO: state the field that caused the error (based upon the response)
    def field
      @field
    end
  end

  class HighRiskTransactionError < RuntimeError
  end

  class << self
    # Lets you configure which ActionMailer class contains appropriate
    # mailings for invoices, expiration warnings, and expiration notices.
    # You'll probably want to create your own, based on lib/subscription_mailer.rb.
    attr_writer :mailer
    def mailer
      @mailer ||= SubscriptionMailer
    end

    # The gateway of choice. Default gateway is a stubbed testing gateway.
    attr_writer :gateway
    def gateway
      @gateway ||= ActiveMerchant::Billing::BogusTrustCommerce.new
    end

    def purchase(amount, credit_card)
      credit_card=credit_card.billing_key if credit_card.billing_key
      # The purchase may not success if the card was just stored; if so, back off exponentially
      tries = 0
      while(tries < 5) # NOTE - We usually break out of this early
        #my_log nil, 'Attempting purchase. Tries so far:', tries, '(sleeping ', tries**2, 'seconds)'
        sleep tries**2 # 0 seconds the first try... if all iterations run, this will take 30 seconds
        response = Freemium.gateway.purchase(amount, credit_card)
        # Break out of here unless we hit a narrow list of problems -- a rejected card is NOT cause to try again.
        if (response.params[:success].blank? || response.params[:success] == false) && response.params['errortype'].present? && ['linkfailure', 'failtoprocess', 'nosuchbillingid'].include?(response.params['errortype'])
          # We had a technical failure and can safely try the charge again
          #my_log nil, 'PURCHASE TECHNICAL FAILURE!', response.params[:errortype], '; tries:', tries, '; response was', response.inspect
          tries += 1
        else
          #my_log nil, 'All hell did not break loose, so we are not trying again', response.inspect
          break
        end
      end
      translated_response=self.active_merchant_trans_params(response, :amount_cents => amount.cents, :retries => tries)
    end

    def refund(tran, amount=nil)
      amount ||= tran.amount
      my_log 'kbrock','Freemium#refund', amount.to_s, tran.inspect
      amount = Money.new(amount) unless amount.is_a?(Money)
      response = Freemium.gateway.credit(amount, tran.gateway_transaction_id)
      my_log 'kbrock','Freemium#refund', response.inspect
      translated_response=self.active_merchant_trans_params(response,:amount_cents => - amount.cents)
    end

    # You need to specify whether Freemium or your gateway's ARB module will control
    # the billing process. If your gateway's ARB controls the billing process, then
    # Freemium will simply try and keep up-to-date on transactions.
    #
    # Rails is puking when they are trying to reload the subscription class.
    # Manually including the billing handler in the subscription class
    def billing_handler=(val)
      # case val
      #   when :manual:   FreemiumSubscription.send(:include, Freemium::ManualBilling)
      #   when :gateway:  FreemiumSubscription.send(:include, Freemium::RecurringBilling)
      #   else raise "unknown billing_handler: #{val}"
      # end
    end

    # How many days to keep an account active after it fails to pay.
    attr_writer :days_grace
    def days_grace
      @days_grace ||= 3
    end
    
    # How many days in an initial free trial?
    attr_writer :days_free_trial
    def days_free_trial
      @days_free_trial ||= 0
    end
    attr_writer :destroy_credit_card_for_free_accounts

    def destroy_credit_card_for_free_accounts
      if @destroy_credit_card_for_free_accounts.nil?
        @destroy_credit_card_for_free_accounts = true
      end
      @destroy_credit_card_for_free_accounts
    end

    # What plan to assign to subscriptions that have expired. May be nil.
    attr_writer :expired_plan
    def expired_plan
      #unless defined?(@expired_plan)
      #  @expired_plan =   FreemiumSubscriptionPlan.find_by_redemption_key(expired_plan_key.to_s) unless expired_plan_key.nil?
      #  @expired_plan ||= FreemiumSubscriptionPlan.find(:first, :conditions => "rate_cents = 0")
      #end
      #@expired_plan
      #@expired_plan ||= FreemiumSubscriptionPlan.find_by_redemption_key(expired_plan_key) unless expired_plan_key.nil?
      exp=@expired_plan
      exp||=FreemiumSubscriptionPlan.find_by_redemption_key(expired_plan_key) unless expired_plan_key.nil?
      exp||=FreemiumSubscriptionPlan.find(:first, :conditions => "rate_cents = 0")
    end

    # It's easier to assign a plan by it's key (so you don't get errors before you run migrations)
    attr_accessor :expired_plan_key
    def expired_plan_key=(value)
      #@expired_plan=nil
      @expired_plan_key=value.present? ? value.to_s : nil
    end

    # If you want to receive admin reports, enter an email (or list of emails) here.
    # These will be bcc'd on all SubscriptionMailer emails, and will also receive the
    # admin activity report.
    attr_accessor :admin_report_recipients
    attr_accessor :admin_report_recipient_ids

    attr_writer :logger
    def logger
      @logger ||= Rails.logger
    end

    #@cvv_check = false
    #@send_warnings=true

    # Set to true to check cvv codes for successful credit card store transactions
    # This will require that a cvv was sent across and stored
    attr_accessor :cvv_check

    # Set to true to email silent warning emails
    attr_accessor :send_warnings

    def params
      {
        :days_grace => @days_grace,
        :days_free_trial => @days_free_trial,
        :destroy_credit_card_for_free_accounts => @destroy_credit_card_for_free_accounts,
        :expired_plan_id => @expired_plan.nil? ? nil : @expired_plan.id,
        :expired_plan_key => @expired_plan_key,
        :cvv_check => @cvv_check,
        :send_warnings => @send_warnings
      }
    end

    protected
    def active_merchant_trans_params(response, other_params={})
      #For the first charge, if there is no billing id, don't want to erase the new billing id with the previous (nil) value
      #other_params.delete(:billing_key) if other_params[:billing_key].blank?
      message=response.message
      begin
        if ! response.success?
          message+= ':' + response.params['offenders'].join(", ")
        end
      rescue
      end
      {
        :success                => response.success?,
        :gateway_transaction_id => response.params['transid'],
        #:amount_cents           =>response.params['paid_amount'].to_f * 100, # subscription
        :message                => message
      }.merge(other_params)
    end
  end
end