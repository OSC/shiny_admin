class ManagedFile
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

  def setfacl(path, acl)
    o, e, s = Open3.capture3("nfs4_setfacl -S -", :stdin_data => acl)
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
  # remove o from A::OWNER@: line
  # strip whitespace
  def sanitize_acl_for_comparison(acl)
    acl.sub(/A:g:GROUP/, 'A::GROUP').strip
  end

  def managed_datasets
    installed_datasets(Configuration.app_dataset_root)
  end

  def dirs
    Configuration.app_dataset_root.glob("**/*").select(&:directory?) - managed_datasets
  end

  def files
    Configuration.app_dataset_root.glob("**/*").select(&:file?)
  end

  # Set the facl on the path only if there is a difference.
  # Raise an exception if a problem occurs either getting or setting the facl.
  #
  # @return true if FACL modified; false if no change applied
  def fix_facl(path, acl)
    if facls_different?(get_facl(path), acl)
      set_facl(path, acl)
      true
    else
      false
    end
  end

  def fix_app_permissions
    log = { updated: [], failed: [] }

    Mapping.installed_apps.each do |path|
      begin
        log[:updated] << path if fix_facl path, directory_user_restricted_acl_template(Mapping.users_that_have_mappings_to_app(path))
      rescue => e
        log[:failed] << { path: path, error: e.message }
      end
    end

    log
  end

  # fix the permissions of all the files in the dataset_root directory
  def fix_dataset_root_permissions
    log = { updated: [], failed: [] }

    dirs.each do |path|
      begin
        log[:updated] << path if fix_facl(path, directory_acl_template)
      rescue => e
        log[:failed] << { path: path, error: e.message }
      end
    end

    files.each do |path|
      begin
        log[:updated] << path if fix_facl(path, file_acl_template)
      rescue => e
        log[:failed] << { path: path, error: e.message }
      end
    end

    managed_datasets.each do |path|
      begin
        log[:updated] << path if fix_facl(path, directory_user_restricted_acl_template(Mapping.users_that_have_mappings_to_dataset(path)))
      rescue => e
        log[:failed] << { path: path, error: e.message }
      end
    end

    log
  end
end
