require 'test_helper'
require 'mocha/test_unit'
require 'fileutils'
require 'pathname'


class MappingTest < ActiveSupport::TestCase
  def setup
    @dataset_root = Pathname.new(ENV['APP_DATASET_ROOT'])
    @app_root = Pathname.new(ENV['SHARED_APPS_ROOT'])
    @existent_ds_path_00 = @dataset_root.join('test_ds_00')
    @existent_ds_path_01 = @dataset_root.join('test_ds_01')
    @existent_app_path_00 = @app_root.join('test_app_00')
    @existent_app_path_01 = @app_root.join('test_app_01')

    @testing_dirs = [
      @existent_ds_path_00,
      @existent_app_path_00,
      @existent_ds_path_01,
      @existent_app_path_01,
    ]

    @testing_dirs.each { |dir| FileUtils.mkdir_p(dir) }
  end

  def teardown
    @testing_dirs.each { |dir| FileUtils.rmdir(dir) }
  end

  # # ============================ #

  def test_add_mapping_adds_facls
    user = ENV['USER']
    mapping = Mapping.new(user: user, app: @existent_app_path_00, dataset: @existent_ds_path_00)

    `nfs4_setfacl -a 'A:g:GROUP@:rxtncCy' #{@existent_app_path_00.to_s}`
    `nfs4_setfacl -a 'A:g:GROUP@:rxtncC' #{@existent_ds_path_00.to_s}`

    # - Directory exists
    # - Directory has group C attribute set
    # - User is a member of the group

    assert mapping.should_add_facl?(@existent_app_path_00)
    assert mapping.should_add_facl?(@existent_ds_path_00)
  end

  def test_facls_should_not_be_set_if_admin_does_not_own_the_files
    unowned_dataset = Pathname.new('/dev/null')
    mapping = Mapping.new(user: 'efranz', app: @existent_app_path_00, dataset: unowned_dataset)

    `nfs4_setfacl -a 'A:g:GROUP@:rxtncCy' #{@existent_app_path_00.to_s}`

    # - App directory exists
    # - App directory has group C attribute set
    # - Cannot change /dev/null
    # - User is a member of the group

    assert mapping.should_add_facl?(@existent_app_path_00)
    assert !mapping.should_add_facl?(unowned_dataset)
  end

  def test_existing_facls_are_not_duplicated
    mapping = Mapping.new(user: 'efranz', app: @existent_app_path_00, dataset: @existent_ds_path_00)

    # Ensure that the group C attribute is set
    `nfs4_setfacl -a 'A:g:GROUP@:rxtncCy' #{@existent_app_path_00.to_s}`
    `nfs4_setfacl -a 'A:g:GROUP@:rxtncCy' #{@existent_ds_path_00.to_s}`

    # Give efranz@osc.edu rx permissions on the files
    `nfs4_setfacl -a 'A::efranz@osc.edu:rx' #{@existent_app_path_00.to_s}`
    `nfs4_setfacl -a 'A::efranz@osc.edu:rx' #{@existent_ds_path_00.to_s}`

    assert !mapping.should_add_facl?(mapping.app)
    assert !mapping.should_add_facl?(mapping.dataset)
  end

  def test_facls_are_not_removed_if_similar_mappings_exist
    # Ensure that the group C attribute is set
    `nfs4_setfacl -a 'A:g:GROUP@:rxtncCy' #{@existent_app_path_00.to_s}`
    `nfs4_setfacl -a 'A:g:GROUP@:rxtncCy' #{@existent_app_path_01.to_s}`
    `nfs4_setfacl -a 'A:g:GROUP@:rxtncCy' #{@existent_ds_path_00.to_s}`

    mapping_a = Mapping.new(user: 'efranz', app: @existent_app_path_00, dataset: @existent_ds_path_00)
    assert mapping_a.save

    mapping_b = Mapping.new(user: 'efranz', app: @existent_app_path_01, dataset: @existent_ds_path_00)
    assert mapping_b.save

    mapping_b.expects(:rx_facl_exists?).returns(true).twice

    # The app-user mapping is unique
    assert mapping_b.should_remove_facl?(mapping_b.app)
    # There are multiple instances of the same dataset
    assert !mapping_b.should_remove_facl?(mapping_b.dataset)
  end

  def test_facls_are_removed_if_no_similar_mappings_exist
    # Ensure that the group C attribute is set
    `nfs4_setfacl -a 'A:g:GROUP@:rxtncCy' #{@existent_app_path_00.to_s}`
    `nfs4_setfacl -a 'A:g:GROUP@:rxtncCy' #{@existent_ds_path_00.to_s}`

    # Give efranz@osc.edu rx permissions on the files
    `nfs4_setfacl -a 'A::efranz@osc.edu:rx' #{@existent_app_path_00.to_s}`
    `nfs4_setfacl -a 'A::efranz@osc.edu:rx' #{@existent_ds_path_00.to_s}`

    mapping = Mapping.new(user: 'user', app: @existent_app_path_00, dataset: @existent_ds_path_00)
    mapping.save

    mapping.expects(:rx_facl_exists?).returns(true).twice

    assert mapping.should_remove_facl?(mapping.app)
    assert mapping.should_remove_facl?(mapping.dataset)
  end
end
