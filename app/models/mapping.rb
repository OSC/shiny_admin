require 'ood_support'
require 'pathname'
require 'yaml/store'

class Mapping < ActiveRecord::Base
  attr_accessor :save_message
  validates :user, :app, :dataset, presence: true
  YAML_FILE_PATH = Pathname.new(ENV['APP_PROJECT_SPACE']).expand_path().join('mappings.yaml')
  APP_ROOT = Pathname.new(ENV['APP_PROJECT_SPACE']).expand_path()

  def dataset
    Pathname.new(super)
  end

  def self.datasets
    select(:dataset).distinct.order(:dataset).pluck(:dataset)
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

  def self.destroy_and_remove_facls(id)
    begin
      mapping = find(id)
      mapping.destroy
      @save_message = 'Mapping successfully destroyed.'

      return true
    rescue OodSupport::InvalidPath, OodSupport::BadExitCode => e
      @save_message = 'Unable to destroy mapping because ' + e.to_s

      return false
    end
  end

  def is_still_valid?
    app_exists = app_full_path.directory?
    dataset_exists = dataset.directory?

    return app_exists && dataset_exists && user_has_permissions_on_both
  end

  def app_full_path
    APP_ROOT.join(app)
  end

  def to_hash
    {:app => app, :user => user, :dataset => dataset, :extensions => extensions}
  end

  def save_and_set_facls
    begin
      success = save
      @save_message = 'Mapping successfully created.'

      return true
    rescue ActiveRecord::RecordNotUnique => e
      @save_message = "Unable to create duplicate mapping between #{user}, #{app} and #{dataset}"
      
      return false
    rescue OodSupport::InvalidPath, OodSupport::BadExitCode => e
      @save_message = "Unable to set FACLS because " + e.to_s
      
      return false
    end
  end

  # Only change FACLs if they can and need to be changed
  def should_add_facl?(path)
    !rx_acl_exists_for_path?(path) && can_change_facls?(path)
  end

  def should_remove_dataset_facl?
    dataset_uniq_for_user? && rx_acl_exists_for_path?(dataset) && can_change_facls?(dataset)
  end

  def should_remove_app_facl?
    app_uniq_for_user? && rx_acl_exists_for_path?(app) && can_change_facls?(app_full_path)
  end

  # Handle FACL setting / removal

  before_save do |mapping|
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

  def dataset_uniq_for_user?
    Mapping.where(user: user, dataset: dataset).count <= 1
  end

  def app_uniq_for_user?
    Mapping.where(user: user, app: app).count <= 1
  end

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

  def rx_acl_exists_for_path?(path)
    begin
      domain = ENV['FACL_USER_DOMAIN']
      acl = OodSupport::ACLs::Nfs4ACL.get_facl(path: dataset)
      expected = build_facl_entry_for_user('user', domain)

      return acl.entries.include?(expected)
    rescue
      return false
    end
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
  # Data sets may be stored in non-standard locations, and owned by users
  # other than the admin user. In the case of a non-owned dataset a mapping
  # may be valid, but the admin user will not be able to set FACLS, and
  # should not try.
  def can_change_facls?(path)
    owns = false
    begin
      owns = path.owned?
    rescue
    end

    owns
  end

  # Add user FACLs to app and dataset
  # @return errors [Exception]
  def add_user_facls(mapping)
    absolute_app_path = APP_ROOT.join(mapping.app)

    # FIXME using the environment for FACL_USER_DOMAIN is expedient, but doesn't feel good
    entry = build_facl_entry_for_user(mapping.user, ENV['FACL_USER_DOMAIN'])
    errors = nil
    # Consider doing this in a transactional manner: everything succeeds or it all gets rolled back
    begin
      acl = OodSupport::ACLs::Nfs4ACL.add_facl(path: absolute_app_path, entry: entry)
      acl = OodSupport::ACLs::Nfs4ACL.add_facl(path: mapping.dataset, entry: entry)
    rescue OodSupport::InvalidPath, OodSupport::BadExitCode => e
      errors = e
    end

    return errors
  end

  # Remove FACLS for user from app and dataset
  def remove_user_facls(mapping)
    absolute_app_path = APP_ROOT.join(mapping.app)

    entry = build_facl_entry_for_user(mapping.user, ENV['FACL_USER_DOMAIN'])
    errors = nil

    begin
      OodSupport::ACLs::Nfs4ACL.rem_facl(path: absolute_app_path, entry: entry)
      OodSupport::ACLs::Nfs4ACL.rem_facl(path: dataset, entry: entry)
    rescue OodSupport::InvalidPath, OodSupport::BadExitCode => e
      errors = e
    end

    return errors
  end
end
