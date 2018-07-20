require 'uri'

module MappingsHelper
  def user_list
    users_from_group = ENV['USERS_FROM_GROUP']
    result = `getent group #{users_from_group}`

    # example output
    #    "wiagstf:*:5362:mrodgers,efranz\n"
    result.strip.split(':')[3].split(',').sort
  end


  # Get a list of the various Shiny apps
  def app_list
    Dir.glob( Configuration.shared_apps_root.join('bc_shiny_*')).sort
  end


  def get_app_name(app_path)
    URI(app_path).path.split('/').last
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
end
