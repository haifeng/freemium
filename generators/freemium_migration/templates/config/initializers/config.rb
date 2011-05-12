# Sample configuration, but this will get you bootstrapped with BrainTree
# TODO:
# - information on where to register...
# - setting up production passwords...
# - better way to do production/test changes?
 
Freemium.gateway = ActiveMerchant::Billing::BraintreeGateway.new(:login => 'demo', :password =>'password')
#Freemium.gateway = ActiveMerchant::Billing::TrustCommerceGateway.new(:login => 'TestMerchant', :password=>'password')
 
# If you want Freemium to take care of the billing itself
# (ie, handle everything within your app, with recurring payments via cron
# or some other batch job)
#  use :manual
#
# if you want to use the gateways recuring payment system
#  use :gateway
Freemium.billing_handler = :manual
 
# the class name of mailer used to send out emails to subscriber
Freemium.mailer = SubscriptionMailer
 
# uncomment to be cc'ed on all freemium emails that go out to the user
#Freemium.admin_report_recipients = %w{admin@site.com}
 
# the grace period, in days, before Freemium triggers additional mails
# for the client. Defaults to 3
Freemium.days_grace = 3
 
# would you like to offer a free trial? Change this to specify the
# length of the trial. Defaults to 0 days
Freemium.days_free_trial = 30
 
##### See vendor/plugins/freemium/freemium.rb for additional choices
 
if RAILS_ENV == 'production'
  # put your production password information here....
  Freemium.gateway.username = "demo"
  Freemium.gateway.password = "password"
elsif RAILS_ENV == 'test'
  # prevents you from calling BrainTree during your tests
  Freemium.gateway = ActiveMerchant::Billing::BogusGateway.new
end