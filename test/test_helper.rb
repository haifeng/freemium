ENV["RAILS_ENV"] = "test"

# load the support libraries
require 'test/unit'
require 'rubygems'
gem 'rails', '~> 2.3.0'
require 'active_record'
require 'active_record/fixtures'
require 'action_mailer'
require 'mocha'
require 'timecop'

# establish the database connection
ActiveRecord::Base.configurations = YAML::load(IO.read(File.dirname(__FILE__) + '/db/database.yml'))
ActiveRecord::Base.establish_connection('active_record_merge_test')

# capture the logging
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")

# load the schema
$stdout = File.open('/dev/null', 'w')
load(File.dirname(__FILE__) + "/db/schema.rb")
$stdout = STDOUT

# configure the TestCase settings
class ActiveSupport::TestCase
  include ActiveRecord::TestFixtures
  
  self.use_transactional_fixtures = true
  self.use_instantiated_fixtures  = false
  self.fixture_path = File.dirname(__FILE__) + '/fixtures/'
end

# disable actual email delivery
ActionMailer::Base.delivery_method = :test

# load the code-to-be-tested
ActiveSupport::Dependencies.load_paths << File.dirname(__FILE__) + '/../lib' # for ActiveSupport autoloading
require File.dirname(__FILE__) + '/../init'

# load the ActiveRecord models
require File.dirname(__FILE__) + '/db/models'

require 'factory_girl'

FreemiumFeatureSet.config_file = File.dirname(__FILE__) + '/freemium_feature_sets.yml'

Freemium.gateway = ActiveMerchant::Billing::BogusTrustCommerceGateway.new
#Freemium.gateway = ActiveMerchant::Billing::BraintreeGateway.new(:login => 'demo', :password =>'password')
#Freemium.gateway = ActiveMerchant::Billing::TrustCommerceGateway.new(:login => 'TestMerchant', :password=>'password')
#hacks - don't have proper handling in gateway
# ActiveMerchant::Billing::TrustCommerceGateway.class_eval do
#   def purchase(money, creditcard_or_billing_id, options = {})
#     BogusGateway.new().purchase(money,creditcard_or_billing_id, options)
#   end
#   def store(cc, options)
#     BogusGateway.new().store(cc,options)
#   end
# end