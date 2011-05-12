# == Schema Information
# Schema version: 201001225114910
#
# Table name: freemium_feature_sets
#
#  id     :integer       primary key
#  name   :string        
#  status :string        default({:limit=>1})
#

#A set of features for a particular subscription plan
#feature sets are stored in a yml file since they don't change that often
class FreemiumFeatureSet# < ActiveRecord::Base
  #include NonActiveRecordModel
  #set_table_name 'freemium_feature_sets'

  attr_accessor :id, :name, :ads, :unlimited
  # column :id,        :integer
  # column :name,      :string
  # column :ads,       :boolean
  # column :unlimited, :boolean

  def initialize(args)
    args.each_pair do |n,v|
      self.send(n+'=',v)
    end
  end

  def method_missing(method, *args, &block)
    # forward named routes
    if method.to_s.include? '?'
      send(method.to_s[0..-2], *args, &block)
    else
      super
    end
  end

  def self.find(id)
    self.all_hash[id.to_i]
  end

  def self.find_by_code(code)
    find_all_by_string(:code,name).first
  end

  def self.find_by_name(name)
    find_all_by_string(:name,name).first
  end

  protected

  def self.find_all_by_string(field,value)
    value=value.downcase if value.respond_to?(:downcase)
    self.all.select {|r| r.send(field).to_s.downcase == value }
  end

  cattr_accessor :config_file
  def self.config_file
    @@config_file ||= File.join(RAILS_ROOT, 'config', "#{table_name}.yml")
  end

  cattr_accessor :data_set
  self.data_set = nil

  def self.all
    self.all_hash.values
  end

  def self.all_hash
    if @@data_set.nil?
      @@data_set = {}
      YAML::load(File.read(self.config_file)).each do |attributes| 
        id = attributes.delete('id').to_i
        obj = self.new(attributes)
        obj.id = id
        @@data_set[id] = obj
      end
    end
    @@data_set
  end
end
