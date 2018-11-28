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

    refute ManagedFile.new.facls_different?(acl1, acl1)
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

    refute ManagedFile.new.facls_different?(acl1, acl2), "Facls that differ only in group flags should be considered the same"
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

    assert ManagedFile.new.facls_different?(acl1, acl2)
  end
end
