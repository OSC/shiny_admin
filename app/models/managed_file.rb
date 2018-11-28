class ManagedFile
  FaclChangeReport = Struct.new(:path, :updated, :error)

  def file_acl_template
    <<~EOF
      A::OWNER@:rwatTnNcCoy
      A:g:GROUP@:rwatncCy
      A::EVERYONE@:rtncy
    EOF
  end


  def directory_acl_template
    <<~EOF
      A::OWNER@:rwaDxtTnNcCoy
      A:g:GROUP@:rwaDxtncCy
      A::EVERYONE@:rxtncy
    EOF
  end

  def user_access_facls(users)
    users.sort.map {|user| "A::#{user}@osc.edu:rx" }.join("\n")
  end

  def directory_user_restricted_acl_template(users)
    <<~EOF
      #{user_access_facls(users)}
      A::OWNER@:rwaDxtTnNcCoy
      A:g:GROUP@:rwaDxtncCy
      A::EVERYONE@:tncy
    EOF
  end

  def dataset_acl_template(path)
    directory_user_restricted_acl_template(Mapping.users_that_have_mappings_to_dataset(path))
  end

  def app_acl_template(path)
    directory_user_restricted_acl_template(Mapping.users_that_have_mappings_to_app(path))
  end

  def setfacl(path, acl)
    o, e, s = Open3.capture3("nfs4_setfacl -S -", path.to_s, :stdin_data => acl)
    s.success? ? o : raise(e)
  end

  def getfacl(path)
    o, e, s = Open3.capture3("nfs4_getfacl", path.to_s)
    s.success? ? o : raise(e)
  end

  # Do comparision, but without g
  #
  # e.g.
  # project space vs home directory
  # A::GROUP@:rxtncy vs A:g:GROUP@:rxtncy
  #
  # Can't seem to use OodSupport::Nfs4Entry for this, unfortunately.
  #
  # OodSupport::Nfs4Entry#group_owner_entry? is broken cause it assumes
  # principle is GROUP AND it will contain the g
  #
  def facls_different?(acl1, acl2)
    sanitize_acl_for_comparison(acl1) != sanitize_acl_for_comparison(acl2)
  end

  # remove g from A:g:GROUP line
  # strip whitespace
  def sanitize_acl_for_comparison(acl)
    acl.sub(/A:g:GROUP/, 'A::GROUP').strip
  end

  def managed_datasets
    @managed_datasets ||= installed_datasets(Configuration.app_dataset_root)
  end

  def dataset?(path)
    managed_datasets.include?(path.to_s)
  end

  # Set the facl on the path only if there is a difference.
  # Raise an exception if a problem occurs either getting or setting the facl.
  #
  # @return [true,nil] if FACL modified; [false, nil] if no change applied;
  #         [false, error_message] if exception occurred
  def fix_facl(path, acl)
    if facls_different?(get_facl(path), acl)
      set_facl(path, acl)

      FaclChangeReport.new(path, true)
    else
      FaclChangeReport.new(path, false)
    end
  rescue => e
    FaclChangeReport.new(path, false, "#{e.class}: #{e.message}")
  end

  # Fix permissions for datasets, using Mapping.users_that_have_mappings_to_dataset(path) to determine
  # if the user should access
  #
  # @param dataset_root [Pathname] - Configuration.app_dataset_root
  # @param datasets [Array<Pathname>] - installed_datasets(Configuration.app_dataset_root) to determine which paths under dataset_root are actual datasets
  # @return [Array<FaclChangeReport>] array of report objects for each path that was updated or each error
  def fix_dataset_root_permissions(dataset_root, datasets)
    dataset_root.glob("**/*").map { |path|
      if datasets.include?(path)
        fix_facl path, dataset_acl_template(path)
      elsif
        fix_facl path, directory_acl_template
      else
        fix_facl path, file_acl_template
      end
    }.select { |report| report.updated || report.error }
  end

  # Fix permissions for apps, using Mapping.users_that_have_mappings_to_app(path) to determine
  # if the user should access
  #
  # @param apps [Array<Pathname>] - Mapping.installed_apps
  # @return [Array<FaclChangeReport>] array of report objects for each path that was updated or each error
  def fix_app_permissions(apps)
    .map { |path|
      fix_facl(path, app_acl_template(path))
    }.select { |report| report.updated || report.error }
  end
end
