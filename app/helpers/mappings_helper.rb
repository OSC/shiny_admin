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
    glob_results = Dir.glob(
      File.join File.expand_path(
        ENV['APP_PROJECT_SPACE']
      ), 'bc_shiny_*'
    )

    # Create a sorted list of just the App directory
    glob_results.sort
  end


  def get_app_name app_path
    URI(app_path).path.split('/').last
  end


  # Get a list of datasets
  # The list will consist of datasets detected at the configured location and
  # datasets that have been saved to the database but are stored in nonstandard
  # locations.
  def known_datasets
    installed_datasets = Dir.glob(
      File.join File.expand_path(
        ENV['APP_DATASET_ROOT']
      ), '*'
    ).sort

    # Take the union of the two sets of datasets
    installed_datasets | Mapping.datasets
  end
end
