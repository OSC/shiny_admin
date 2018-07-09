require 'ood_support'
require 'yaml/store'

class Mapping < ActiveRecord::Base
  YAML_FILE_PATH = File.join(ENV['APP_PROJECT_SPACE'], 'mappings.yaml')

  [:user, :app, :dataset].each do |field|
    validates field, presence: true
  end


  def is_still_valid?
    app_exists = File.directory?(app_full_path)
    dataset_exists = File.directory?(dataset)
    
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


  def app_full_path
    File.join(ENV['APP_PROJECT_SPACE'], app)
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


  private

  # Check whether a user has read/execute permissions on the app and dataset directories
  # @return [Boolean] does user have correct permissions?
  def user_has_permissions_on_both
    ood_user = OodSupport::User.new(user)
    required_permissions = [:r, :x]
    
    app_acl = OodSupport::ACLs::Nfs4ACL.get_facl(path: app_full_path)
    dataset_acl = nil
    begin
      dataset_acl = OodSupport::ACLs::Nfs4ACL.get_facl(path: dataset)
    rescue OodSupport::InvalidPath
      return false
    end

    for required_permission in required_permissions do
      unless app_acl.allow?(principle: ood_user, permission: required_permission)
        return false
      end

      unless dataset_acl.allow?(principle: ood_user, permission: required_permission)
        return false
      end
    end

    # Everything went well so return true
    return true
  end
end
