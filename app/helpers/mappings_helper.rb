require 'etc'
require 'pathname'

module MappingsHelper
  def user_list
    users_from_group = ENV['USERS_FROM_GROUP']
    result = `getent group #{users_from_group}`

    # example output
    #    "wiagstf:*:5362:mrodgers,efranz\n"
    result.strip.split(':')[3].split(',').sort
  end

  def user_list_help
    "Users list is built from users in group: #{ENV['USERS_FROM_GROUP']}"
  end


  # Get a list of the various Shiny apps
  def app_list
    Dir.glob( Configuration.shared_apps_root.join('bc_shiny_*')).sort.map{|path| Pathname.new(path)}
  end

  def app_list_help
    "App list is built from apps in #{Configuration.shared_apps_root.to_s} with the directory name starting with 'bc_shiny_'"
  end


  def get_app_name(app_path)
    app_path.basename
  end


  # Get a list of datasets
  # The list will consist of datasets detected at the configured location and
  # datasets that have been saved to the database but are stored in nonstandard
  # locations.
  def known_datasets
    installed_datasets = Dir.glob(Configuration.app_dataset_root.join('*')).sort

    # Take the union of the two sets of datasets
    installed_datasets | Mapping.datasets
  end

  def known_datasets_help
   "Known datasets include files or directories under #{Configuration.app_dataset_root.to_s} and arbitrary paths already added to this database" 
  end

  # Attempt to get a full name for the user
  # @return [String]
  def full_username(user)
    full_name = Etc.getpwnam(user).gecos.strip

    full_name.empty? ? user : full_name
  end
end
