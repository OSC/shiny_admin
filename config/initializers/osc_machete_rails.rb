OscMacheteRails.update_status_of_all_active_jobs_on_each_request = false

Rails.configuration.x.title = YAML.load(File.read('manifest.yml'))['name']
