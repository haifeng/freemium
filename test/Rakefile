require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the freemium plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.pattern = 'test/unit/*_test.rb'
  t.verbose = true
end

desc 'Generate documentation for the freemium plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Freemium'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |s|
    s.name = "freemium"
    s.version = "0.1.0"
    #s.rubyforge_project = "rails-footnotes"
    s.summary = "Freemium provides subscription logic on top of active merchant."
    s.email = "keenan@thebrocks.net"
    s.homepage = "http://github.com/kbrock/freemium"
    s.description = %[The origional freemium was a replacement for Active Merchant. One that was more tuned to Subscriptions.
This version tore out the credit card processing and leverages Active Merchant for the payment gateway tasks.
Now this concentrates on the business process of tracking and managing subscriptions.

This version has a lot of changes.]
    s.authors = ['Lance Ivy', 'Keenan Brock']
    s.files =  FileList["[A-Z]*", "{lib,generators,test}/**/*", "init.rb"]
    s.add_dependency 'activemerchant', '>= 1.4.2'
    s.add_dependency 'money', '>= 2.1.5'
  end

  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler, or one of its dependencies, is not available. Install it with: sudo gem install jeweler"
end

begin
  require 'metric_fu'
  MetricFu::Configuration.run do |config|
      #skipping: churn, :stats
      config.metrics  = [:saikuro, :flog, :flay, :reek, :roodi, :rcov]
      # config.graphs   = [:flog, :flay, :reek, :roodi, :rcov]
      config.rcov[:rcov_opts] << "-Itest"
  end
rescue LoadError
end
