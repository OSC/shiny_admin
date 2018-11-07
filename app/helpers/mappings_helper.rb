require 'etc'
require 'pathname'

module MappingsHelper
  def members_of_group(group)
    `ldapsearch -LLL -x "(&(objectclass=oscGroup)(cn=#{group}))"`.scan(/member: cn=(.*),ou=people/).flatten
  end

  def user_list
    members_of_group(Configuration.users_from_group).sort
  end

  def user_select_list
    user_list.map { |user| [display_username(user), user] }
  end

  def user_list_help
    "Users list is built from users in group: #{Configuration.users_from_group}"
  end


  # Get a list of the various Shiny apps
  def app_list
    Configuration.shared_apps_root.children.select(&:directory?).sort
  end

  def app_list_help
    "App list is built from apps in #{Configuration.shared_apps_root.to_s} that are directories."
  end


  def get_app_name(app_path)
    app_path.basename
  end

  def known_datasets_help
   "Known datasets include files or directories under #{Configuration.app_dataset_root.to_s} and arbitrary paths already added to this database" 
  end

  # Attempt to get a full name for the user
  # @return [String]
  def display_username(user)
    full_name = Etc.getpwnam(user).gecos.strip
    full_name = full_name.empty? ? user : full_name

    "#{full_name} - #{user}"
  end
end
