require 'test_helper'
require 'mocha/test_unit'
require 'fileutils'
require 'pathname'


class MappingsHelperTest < ActionView::TestCase
  # For example, if we have this as our /users/PAS1203/bmiadmin/datasets directory root:

  # datasets/
  # ├── franz_hista_alignment
  # │   ├── data.csv
  # │   └── data.rds
  # ├── mrodgers_hista_alignment
  # │   └── data.csv
  # └── PZS0714
  #     ├── foo
  #     │   ├── bar
  #     │   │   └── data.rds
  #     │   └── data.rds
  #     └── mrodgers_hista_alignment
  #         ├── data.csv
  #         └── data.RDS
  # then datasets would be:

  # /users/PAS1203/bmiadmin/datasets/franz_hista_alignment

  # /users/PAS1203/bmiadmin/datasets/PZS0714/mrodgers_hista_alignment
  # # => notice you need a case insensitive check of the extension RDS or rds etc.

  # /users/PAS1203/bmiadmin/datasets/PZS0714/foo
  # # => notice bar is not a dataset because it is contained in foo

  def setup
    @path_root = Pathname.new(Dir.mktmpdir)
    @paths = [
      'datasets/franz_hista_alignment/data.rds',
      'datasets/mrodgers_hista_alignment/data.csv',
      'datasets/PZS0714/foo/bar/data.rds',
      'datasets/PZS0714/foo/data.rds',
      'datasets/PZS0714/mrodgers_hista_alignment/data.RDS',
    ].map{ |path| @path_root + path }

    @paths.each do |path|
      FileUtils.mkdir_p(path.dirname)
      FileUtils.touch(path)
    end
  end

  def teardown
    FileUtils.remove_entry_secure(@path_root)
  end

  def test_installed_datasets
    detected_datasets = installed_datasets(@path_root)

    expected_datasets = [
      'datasets/PZS0714/foo',
      'datasets/PZS0714/mrodgers_hista_alignment',
      'datasets/franz_hista_alignment'
    ].map {|path| @path_root + path}

    assert detected_datasets == expected_datasets
  end
end