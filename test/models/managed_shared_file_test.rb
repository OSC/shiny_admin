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

    # setup
    # create dirs in tmpdir (app_for_efranz, app_for_mrodgers, app_no_one_can_access)
    Dir.mktmpdir(nil, project_dir.to_s) do |tmpdir|
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
