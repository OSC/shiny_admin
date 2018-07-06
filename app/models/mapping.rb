require 'ood_support'
require 'yaml/store'

class Mapping < ActiveRecord::Base
  YAML_FILE_PATH = File.join(ENV['BSIR_PROJECT_SPACE'], 'mappings.yaml')

  [:user, :app, :dataset].each do |field|
    validates field, presence: true
  end


  def is_still_valid?

    app_exists = File.directory?(File.join(ENV['BSIR_PROJECT_SPACE'], app))
    dataset_exists = File.directory?(dataset)
    user_has_permissions_on_both = true  # TODO
    
    return app_exists && dataset_exists && user_has_permissions_on_both
  end


  def self.dump_to_yaml
    mappings = []
    Mapping.find_each do |mapping|
      mappings << mapping.to_hash
    end

    store = YAML::Store.new(YAML_FILE_PATH)

    store.transaction do
      store[:mappings] = mappings
    end
  end


  def to_hash
    {:app => app, :user => user, :dataset => dataset, :extensions => extensions}
  end


  after_create do |mapping|
    Mapping.dump_to_yaml
  end


  after_destroy do |mapping|
    Mapping.dump_to_yaml
  end
end
