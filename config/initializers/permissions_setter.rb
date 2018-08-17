# Be sure to restart your server when you modify this file.

# You can add backtrace silencers for libraries that you're using but don't wish to see in your backtraces.
# Rails.backtrace_cleaner.add_silencer { |line| line =~ /my_noisy_library/ }

# You can also remove all the silencers if you're trying to debug a problem that might stem from framework code.
# Rails.backtrace_cleaner.remove_silencers!
require 'fileutils'

FileUtils.touch(Configuration.yaml_file_path)
FileUtils.touch(Configuration.production_database_path)
FileUtils.chmod(0775, Configuration.yaml_file_path)
FileUtils.chmod(0775, Configuration.production_database_path)
