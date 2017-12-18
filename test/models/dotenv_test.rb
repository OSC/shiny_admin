require 'test_helper'

class DotenvTest < ActiveSupport::TestCase
  test ".env.production.awesim sets correct dataroot for shared apps" do
    Bundler.with_clean_env do
      envs = Dotenv.load('.env.production.awesim')
      name = Pathname.pwd.basename

      assert_equal "usr/#{Etc.getlogin}/#{name}", envs['APP_TOKEN']

      # ~/awesim/data/efranz/pseudofun
      #
      assert_equal "#{Dir.home}/awesim/data/#{Etc.getlogin}/#{name}", envs['OOD_DATAROOT']
      assert_equal "#{Dir.home}/awesim/data/#{Etc.getlogin}/#{name}/production.sqlite3", envs['DATABASE_PATH']
      assert_equal "/pun/usr/#{Etc.getlogin}/#{name}", envs['RAILS_RELATIVE_URL_ROOT']
    end
  end

  test ".env.production.ondemand sets correct dataroot for sys apps" do
    Bundler.with_clean_env do
      envs = Dotenv.load('.env.production.ondemand')
      name = Pathname.pwd.basename

      assert_equal "sys/#{name}", envs['APP_TOKEN']

      # ~/ondemand/data/sys/pseudofun
      #
      assert_equal "#{Dir.home}/ondemand/data/sys/#{name}", envs['OOD_DATAROOT']
      assert_equal "#{Dir.home}/ondemand/data/sys/#{name}/production.sqlite3", envs['DATABASE_PATH']
      assert_equal "/pun/sys/#{name}", envs['RAILS_RELATIVE_URL_ROOT']
    end
  end
end
