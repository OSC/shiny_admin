require 'ood_support'
require 'pathname'
require 'yaml/store'


class Mapping < ActiveRecord::Base
  attr_accessor :save_message
  validates :user, :app, :dataset, presence: true
  YAML_FILE_PATH = Pathname.new(ENV['SHARED_APPS_ROOT']).expand_path().join('mappings.yaml')
  APP_ROOT = Pathname.new(ENV['SHARED_APPS_ROOT']).expand_path()
  FACL_USER_DOMAIN = ENV['FACL_USER_DOMAIN']

  def dataset
    Pathname.new(super)
  end

  def app
    Pathname.new(super)
  end

  # @return [Array<String>]
  def self.datasets
    select(:dataset).distinct.order(:dataset).pluck(:dataset)
  end

  def self.dump_to_yaml
    mappings = []
    Mapping.find_each do |mapping|
      mapping_as_hash = mapping.to_hash
      mapping_as_hash[:app] = mapping_as_hash[:app].to_s
      mapping_as_hash[:dataset] = mapping_as_hash[:dataset].to_s

      mappings << mapping_as_hash
    end

    store = YAML::Store.new(YAML_FILE_PATH)

    store.transaction do
      store[:mappings] = mappings
    end
  end

  # Ensure that a user can use a given mapping
  # @return [Boolean]
  def is_still_valid?
    return app.exist? && dataset.exist? && user_has_permissions_on_both?
  end

  # @return [Hash]
  def to_hash
    {:app => app, :user => user, :dataset => dataset, :extensions => extensions}
  end

  def self.destroy_and_remove_facls(id)
    begin
      mapping = find(id)
      mapping.remove_rx_facl(mapping.dataset)
      mapping.remove_rx_facl(mapping.app)
      mapping.destroy
      dump_to_yaml
      @save_message = 'Mapping successfully destroyed.'

      return true
    rescue OodSupport::InvalidPath, OodSupport::BadExitCode => e
      @save_message = 'Unable to destroy mapping because ' + e.to_s

      return false
    end
  end

  # Custom save method
  def save_and_set_facls
    begin
      success = save

      add_rx_facl(app)
      add_rx_facl(dataset)
      Mapping.dump_to_yaml
      @save_message = 'Mapping successfully created.'

      return true
    rescue ActiveRecord::RecordNotUnique => e
      @save_message = "Unable to create duplicate mapping between #{user}, #{app}, and #{dataset}"
      
      return false
    rescue OodSupport::InvalidPath, OodSupport::BadExitCode => e
      @save_message = "Unable to set FACLS because " + e.to_s
      
      return false
    end
  end

  # @return [Boolean]
  def should_add_facl?(pathname)
    # Calling owned first protects rx_facl_exists? from throwing InvalidPath
    pathname.owned? && ! rx_facl_exists?(pathname)
  end

  # Idempotently add a RX entry to the ACL for a file
  def add_rx_facl(pathname)
    return unless should_add_facl?(pathname)

    entry = build_facl_entry_for_user(user, FACL_USER_DOMAIN)
    OodSupport::ACLs::Nfs4ACL.add_facl(path: pathname, entry: entry)
  end

  # Check if pathname / user combination occurs once or less in the database
  # @return [Boolean] 
  def pathname_uniq_for_user?(pathname)    
    Mapping.where(
      '(app = ? OR dataset = ?) AND user = ?',
      pathname.to_s, pathname.to_s, user
    ).count <= 1
  end

  # @return [Boolean]
  def should_remove_facl?(pathname)
    pathname.owned? && rx_facl_exists?(pathname) && pathname_uniq_for_user?(pathname)
  end

  # Conditionally remove RX FACLs
  #
  # Remove only if file exists, is owned, entry exists, user + (dataset, app)
  # combination is last in database
  def remove_rx_facl(pathname)
    return unless should_remove_facl?(pathname)

    entry = build_facl_entry_for_user(user, FACL_USER_DOMAIN)
    OodSupport::ACLs::Nfs4ACL.rem_facl(path: pathname, entry: entry)
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

  # Check if a RX ACL entry exists on pathname
  # @return [Boolean]
  def rx_facl_exists?(pathname)
    begin
      acl = OodSupport::ACLs::Nfs4ACL.get_facl(path: pathname)
      expected = build_facl_entry_for_user(user, FACL_USER_DOMAIN)

      return acl.entries.include?(expected)
    rescue
      return false
    end
  end

  # Check whether a user has read/execute permissions on the app and dataset directories
  # @return [Boolean] does user have correct permissions?
  def user_has_permissions_on_both?
    ood_user = OodSupport::User.new(user)
    required_permissions = [:r, :x]

    app_facl = OodSupport::ACLs::Nfs4ACL.get_facl(path: app)
    dataset_facl = nil
    begin
      dataset_facl = OodSupport::ACLs::Nfs4ACL.get_facl(path: dataset)
    rescue OodSupport::InvalidPath, OodSupport::BadExitCode
      return false
    end

    for required_permission in required_permissions do
      unless app_facl.allow?(principle: ood_user, permission: required_permission)
        return false
      end

      unless dataset_facl.allow?(principle: ood_user, permission: required_permission)
        return false
      end
    end

    # Everything went well so return true
    return true
  end
end
