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

  # Handle FACL setting / removal

  before_save do |mapping|
    logger.info('Can change FACL' + can_change_facls?(mapping.dataset).to_s)
    # Short circuit if the admin user cannot set FACLS
    if can_change_facls?(mapping.dataset)
      errors = add_user_facls(mapping)
      unless errors.nil?
        raise errors
      end
    end
  end

  before_destroy do |mapping|
    # Short circuit if the admin user cannot set FACLS
    if can_change_facls?(mapping.dataset)
      errors = remove_user_facls(mapping)
      unless errors.nil?
        raise errors
      end
    end
  end

  # Update the YAML Dump

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
    rescue OodSupport::InvalidPath, OodSupport::BadExitCode
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

  # Build FACL for user and domain combination
  # @return [Nfs4Entry]
  def build_facl_entry_for_user(user, domain)
    OodSupport::ACLs::Nfs4Entry.new(
      type: :A,
      flags: [],
      principle: user,
      domain: domain,
      permissions: [:r, :x]
    )
  end

  # Determine if FACLs can be set by the admin user
  #
  # Data sets may be stored in non-standard locations, and oqwned by users
  # other than the admin user. In the case of a non-owned dataset a mapping
  # may be valid, but the admin user will not be able to set FACLS, and
  # should not try.
  def can_change_facls?(path)
    File.stat(path).owned?
  end


  # Add user FACLs to app and dataset
  # @return errors [Exception]
  def add_user_facls(mapping)
    absolute_app_path = File.join(
      File.expand_path(ENV['APP_PROJECT_SPACE']),
      mapping.app
    )

    # FIXME using the environment for FACL_USER_DOMAIN is expedient, but doesn't feel good
    entry = build_facl_entry_for_user(mapping.user, ENV['FACL_USER_DOMAIN'])
    errors = nil
    # Consider doing this in a transactional manner: everything succeeds or it all gets rolled back
    begin
      acl = OodSupport::ACLs::Nfs4ACL.add_facl(path: absolute_app_path, entry: entry)
      acl = OodSupport::ACLs::Nfs4ACL.add_facl(path: mapping.dataset, entry: entry)
    rescue Exception => e
      errors = e
    end

    return errors
  end

  # Remove FACLS for user from app and dataset
  def remove_user_facls(mapping)
    absolute_app_path = File.join(
      File.expand_path(
        ENV['APP_PROJECT_SPACE']
      ),
      mapping.app
    )

    entry = build_facl_entry_for_user(mapping.user, ENV['FACL_USER_DOMAIN'])
    errors = nil

    begin
      OodSupport::ACLs::Nfs4ACL.rem_facl(path: absolute_app_path, entry: entry)
      OodSupport::ACLs::Nfs4ACL.rem_facl(path: dataset, entry: entry)
    rescue Exception => e
      errors = e
    end

    return errors
  end
end
