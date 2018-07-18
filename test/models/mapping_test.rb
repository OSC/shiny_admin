require 'test_helper'
require 'mocha/test_unit'
require 'fileutils'


class MappingTest < ActiveSupport::TestCase
  def setup
    @dataset_root = ENV['APP_DATASET_ROOT']
    @app_root = ENV['APP_PROJECT_SPACE']
    @existent_ds_path = File.join(@dataset_root, 'test_ds_00')
    @existent_app_path = File.join(@app_root, 'test_app_00')

    @testing_dirs = [
      @existent_ds_path,
      @existent_app_path,
    ]

    @testing_dirs.each { |dir| FileUtils.mkdir_p(dir) }
  end

  def teardown
    @testing_dirs.each { |dir| FileUtils.rmdir(dir) }
  end

  # ============================ #

  def test_that_testing_is_properly_setup
    assert true
  end

  # Test FACL settings/removing logic

  # Files unowned by admin
  def test_facls_should_not_be_set_if_admin_does_not_own_the_files
    mapping = Mapping.new(user: 'user', app: 'test_app_00', dataset: '/dev/null')

    assert mapping.should_add_facl?(mapping.dataset) == false
  end

  # Setting FACL entry for the first time
  def test_facls_are_set_if_not_already_set
    mapping = Mapping.new(user: 'user', app: 'test_app_00', dataset: @existent_ds_path)

    assert mapping.should_add_facl?(mapping.dataset) == true
  end

  # Setting FACL entry already exists
  def test_facls_are_not_be_set_if_already_set
    mapping = Mapping.new(user: 'user', app: 'test_app_00', dataset: @existent_ds_path)
    mapping.expects(:rx_acl_exists_for_path?).returns(true)

    assert mapping.should_add_facl?(mapping.dataset) == false
  end

  # Removing FACL entry NOT last of its kind
  def test_facls_are_not_removed_if_similar_mappings_exist
    mapping = Mapping.new(user: 'user', app: 'test_app_00', dataset: @existent_ds_path)
    mapping.expects(:dataset_uniq_for_user?).returns(false)
    mapping.expects(:app_uniq_for_user?).returns(false)

    assert mapping.should_remove_dataset_facl? == false
    assert mapping.should_remove_app_facl? == false
  end

  # Removing FACL entry last of its kind
  def test_facls_are_removed_if_no_similar_mappings_exist
    mapping = Mapping.new(user: 'user', app: 'test_app_00', dataset: @existent_ds_path)

    mapping.expects(:dataset_uniq_for_user?).returns(true)
    mapping.expects(:rx_acl_exists_for_path?).returns(true)
    assert mapping.should_remove_dataset_facl? == true

    mapping.expects(:app_uniq_for_user?).returns(true)
    mapping.expects(:rx_acl_exists_for_path?).returns(true)
    assert mapping.should_remove_app_facl? == true
  end

  # Test database operations

  # TODO
end
