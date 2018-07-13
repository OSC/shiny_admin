require 'json'

DATA_ROOT = ENV['OOD_DATAROOT']
mappings = Mapping.create([
  {:user => 'mrodgers', :app => 'App #1', :dataset => File.join(DATA_ROOT, 'ds_01'), :extensions => JSON.dump({})},
  {:user => 'mrodgers', :app => 'App #1', :dataset => File.join(DATA_ROOT, 'ds_02'), :extensions => JSON.dump({})},
  {:user => 'mrodgers', :app => 'App #1', :dataset => File.join(DATA_ROOT, 'ds_03'), :extensions => JSON.dump({})},
  {:user => 'efranz', :app => 'App #2', :dataset => File.join(DATA_ROOT, 'ds_01'), :extensions => JSON.dump({})},
  {:user => 'efranz', :app => 'App #2', :dataset => File.join(DATA_ROOT, 'ds_02'), :extensions => JSON.dump({})},
  {:user => 'efranz', :app => 'App #3', :dataset => '/users/PZS0002/mrodgers/fake_data_root/d03', :extensions => JSON.dump({})},
])