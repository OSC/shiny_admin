require 'test_helper'
require 'mocha/test_unit'
require 'fileutils'
require 'pathname'

class ManagedSharedFileTest < ActiveSupport::TestCase
  def test_comparision_of_two_same_facls
    acl1 = <<~EOF
      A::OWNER@:rwatTnNcCoy
      A:g:GROUP@:rwatncCy
      A::EVERYONE@:rtncy
    EOF

    refute ManagedSharedFile.new.facls_different?(acl1, acl1)
  end

  def test_comparision_of_two_facls_with_different_group_flags
    acl1 = <<~EOF
      A::OWNER@:rwatTnNcCoy
      A:g:GROUP@:rwatncCy
      A::EVERYONE@:rtncy
    EOF

    acl2 = <<~EOF
      A::OWNER@:rwatTnNcCoy
      A::GROUP@:rwatncCy
      A::EVERYONE@:rtncy
    EOF

    refute ManagedSharedFile.new.facls_different?(acl1, acl2), "Facls that differ only in group flags should be considered the same"
  end

  def test_comparision_of_two_different_facls
    acl1 = <<~EOF
      A::OWNER@:rwatTnNcCoy
      A:g:GROUP@:rwatncy
      A::EVERYONE@:rtncy
    EOF

    # group has C in this facl
    acl2 = <<~EOF
      A::OWNER@:rwatTnNcCoy
      A::GROUP@:rwatncCy
      A::EVERYONE@:rtncy
    EOF

    assert ManagedSharedFile.new.facls_different?(acl1, acl2)
  end

  def test_app_permissions
    skip "test requires nfs4_setfacl and nfs4_getfacl" if `which nfs4_setfacl`.empty?
    project_dir = Pathname.new('/fs/project/PZS0714')
    skip "need to test in projects space: #{project_dir}" unless project_dir.executable? && project_dir.writable?
    skip "need to be part of group wiagall" unless process_in_group("wiagall")

    Dir.mktmpdir(nil, project_dir.to_s) do |tmpdir|
      # setup
      tmpdir = Pathname.new(tmpdir)

      app_for_efranz = tmpdir.join("app_for_efranz").tap {|p| p.mkpath }
      app_for_mrodgers_and_alanc = tmpdir.join(" app_for_mrodgers_and_alanc").tap {|p| p.mkpath }
      app_no_one_can_access = tmpdir.join("app_no_one_can_access").tap {|p| p.mkpath }

      # mock Mapping.users_that_have_mappings_to_app
      Mapping.stubs(:users_that_have_mappings_to_app).returns([])
      Mapping.stubs(:users_that_have_mappings_to_app).with(app_for_efranz).returns(["efranz"])
      Mapping.stubs(:users_that_have_mappings_to_app).with(app_for_mrodgers_and_alanc).returns(["alanc", "mrodgers"])

      # verify permissions on directories are wide open
      assert_equal ["efranz"], Mapping.users_that_have_mappings_to_app(app_for_efranz)
      assert_equal [], Mapping.users_that_have_mappings_to_app(tmpdir)

      assert 755, mode(app_for_efranz)

      # execute
      changes = ManagedSharedFile.new.fix_app_permissions(tmpdir.children())


      # verify
      assert_equal 3, changes.count # 3 directories affected
      assert 770, mode(app_for_efranz)
      assert 770, mode(app_for_mrodgers_and_alanc)
      assert 770, mode(app_no_one_can_access)
      assert_equal ["efranz"], user_principles(app_for_efranz)
      assert_equal ["alanc", "mrodgers"], user_principles(app_for_mrodgers_and_alanc)
      assert_equal [], user_principles(app_no_one_can_access)

      # execute again and verify no changes required (since its idempotent)
      changes = ManagedSharedFile.new.fix_app_permissions(tmpdir.children())
      assert_equal 0, changes.count, "Files should have already had permissions fixed: #{changes.inspect}"

      # fix group ownership
      refute_equal app_for_efranz.stat.gid, OodSupport::Group.new('wiagall').id
      changes = ManagedSharedFile.new.fix_group_ownership_for_files(tmpdir.children(), 'wiagall')
      assert_equal 3, changes.count # 3 directories affected
      assert_equal app_for_efranz.stat.gid, OodSupport::Group.new('wiagall').id

      changes = ManagedSharedFile.new.fix_group_ownership_for_files(tmpdir.children(), 'wiagall')
      assert_equal 0, changes.count, "Files should have already had group ownership fixed: #{changes.inspect}"
    end
  end

  def test_dataset_permissions
    skip "test requires nfs4_setfacl and nfs4_getfacl" if `which nfs4_setfacl`.empty?
    project_dir = Pathname.new('/fs/project/PZS0714')
    skip "need to test in projects space: #{project_dir}" unless project_dir.executable? && project_dir.writable?
    skip "need to be part of group wiagall" unless process_in_group("wiagall")

    Dir.mktmpdir(nil, project_dir.to_s) do |tmpdir|
      # setup
      tmpdir = Pathname.new(tmpdir)

      dataset1 = tmpdir.join("example/efranz/dataset1").tap {|p| p.mkpath }
      dataset2 = tmpdir.join("example/noone/dataset2").tap {|p| p.mkpath }
      dataset3 = tmpdir.join("example/mrodgers/dataset3").tap {|p| p.mkpath }
      dataset4 = tmpdir.join("alan_and_mrodgers/dataset4").tap {|p| p.mkpath }
      file_in_dataset = dataset4.join("data.rds").tap {|p| FileUtils.touch(p.to_s) }
      dir_in_dataset = dataset4.join("subdir").tap {|p| p.mkpath }


      # mock Mapping.users_that_have_mappings_to_app
      Mapping.stubs(:users_that_have_mappings_to_dataset).returns([])
      Mapping.stubs(:users_that_have_mappings_to_dataset).with(dataset1).returns(["efranz"])
      Mapping.stubs(:users_that_have_mappings_to_dataset).with(dataset3).returns(["mrodgers"])
      Mapping.stubs(:users_that_have_mappings_to_dataset).with(dataset4).returns(["alanc", "mrodgers"])

      # verify permissions on directories are wide open
      assert_equal ["efranz"], Mapping.users_that_have_mappings_to_dataset(dataset1)
      assert_equal [], Mapping.users_that_have_mappings_to_dataset(tmpdir)

      assert 755, mode(dataset1)
      assert 755, mode(dir_in_dataset)
      assert 644, mode(file_in_dataset)

      # execute
      changes = ManagedSharedFile.new.fix_dataset_root_permissions(tmpdir, [dataset1, dataset2, dataset3, dataset4])


      # verify
      assert_equal tmpdir.find.count, changes.count
      assert 770, mode(dataset1)
      assert 770, mode(dataset4)
      assert 775, mode(dataset1.parent)
      assert 775, mode(dir_in_dataset)
      assert 664, mode(file_in_dataset)
      assert_equal ["efranz"], user_principles(dataset1)
      assert_equal ["alanc", "mrodgers"], user_principles(dataset4)
      assert_equal [], user_principles(dataset2)

      # execute again and verify no changes required (since its idempotent)
      changes = ManagedSharedFile.new.fix_dataset_root_permissions(tmpdir, [dataset1, dataset2, dataset3, dataset4])
      assert_equal 0, changes.count, "Files should have already had permissions fixed: #{changes.inspect}"

      # fix group ownership
      refute_equal dataset1.stat.gid, OodSupport::Group.new('wiagall').id
      changes = ManagedSharedFile.new.fix_dataset_root_group_ownership(tmpdir, 'wiagall')
      assert_equal tmpdir.find.count, changes.count
      assert_equal dataset1.stat.gid, OodSupport::Group.new('wiagall').id
      assert_equal file_in_dataset.stat.gid, OodSupport::Group.new('wiagall').id
      assert_equal dir_in_dataset.stat.gid, OodSupport::Group.new('wiagall').id

      changes = ManagedSharedFile.new.fix_dataset_root_group_ownership(tmpdir, 'wiagall')
      assert_equal 0, changes.count, "Files should have already had group ownership fixed: #{changes.inspect}"
    end
  end

  # candidates for OodSupport
  private

  def user_principles(path)
    OodSupport::ACLs::Nfs4ACL.get_facl(path: path).entries.map(&:principle) - ["OWNER", "GROUP", "EVERYONE"]
  end

  def mode(path)
    Pathname.new(path).stat.mode.to_s(8).last(3)
  end

  def process_in_group(group)
    OodSupport::Process.groups.map(&:name).include?(group)
  end
end
