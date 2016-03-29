# Copyright (c) 2013-2016 Cisco and/or its affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require_relative 'ciscotest'
require_relative '../lib/cisco_node_utils/snmpcommunity'

def cleanup_snmp_communities(snmpcommunities)
  snmpcommunities.each_value(&:destroy)
end

def cleanup_snmpcommunity(community)
  community.destroy
end

# TestSnmpCommunity - Minitest for SnmpCommunity node utility
class TestSnmpCommunity < CiscoTestCase
  @skip_unless_supported = 'snmp_community'

  SNMP_COMMUNITY_NAME_STR = 128
  SNMP_GROUP_NAME_STR = 128
  DEFAULT_SNMP_COMMUNITY_GROUP = 'network-operator'
  DEFAULT_SNMP_COMMUNITY_ACL = ''

  def setup
    super
    if platform != :ios_xr
      @default_show_command = 'show run snmp all | no-more'
    else
      @default_show_command = 'show running-config snmp'
    end
  end

  def test_snmpcommunity_collection_empty
    # This test requires all the snmp communities removed from device
    if platform != :ios_xr
      s = @device.cmd('show run snmp all | no-more')
      cmd_prefix = 'snmp-server community'
      # puts "s : #{s}"
      pattern = /#{cmd_prefix}\s\S+\sgroup\s\S+/
      until (md = pattern.match(s)).nil?
        # puts "md : #{md}"
        config("no #{md}")
        s = md.post_match
      end
    else
      config('no snmp-server community com1',
             'no snmp-server community com2',
             'no snmp-server community com12',
             'no snmp-server community com22')
    end
    snmpcommunities = SnmpCommunity.communities
    assert_equal(true, snmpcommunities.empty?,
                 'SnmpCommunity collection is not empty')
  end

  def test_snmpcommunity_collection_not_empty
    snmpcommunities = SnmpCommunity.communities
    cleanup_snmp_communities(snmpcommunities)

    # This test require some snmp community exist in device
    if platform != :ios_xr
      config('snmp-server community com1 group network-admin',
             'snmp-server community com2')
    else
      config('snmp-server community com1',
             'snmp-server community com2')
    end
    snmpcommunities = SnmpCommunity.communities

    assert_equal(false, snmpcommunities.empty?,
                 'SnmpCommunity collection is empty')
    cleanup_snmp_communities(snmpcommunities)
  end

  def test_snmpcommunity_collection_valid
    # This test require some snmp community exist in device
    if platform != :ios_xr
      config('snmp-server community com12 group network-operator',
             'snmp-server community com22 group network-admin')
    else
      config('snmp-server community com12',
             'snmp-server community com22')
    end
    # get collection

    snmpcommunities = SnmpCommunity.communities
    if platform != :ios_xr
      s = @device.cmd('show run snmp all | no-more')
    else
      s = @device.cmd('show running-config snmp')
    end
    cmd = 'snmp-server community'
    snmpcommunities.each do |name, _snmpcommunity|
      line = /#{cmd}\s#{name}\s.*/.match(s)
      # puts "line: #{line}"
      assert_equal(false, line.nil?)
    end
    cleanup_snmp_communities(snmpcommunities)
  end

  def test_snmpcommunity_create_name_nil
    assert_raises(TypeError) do
      if platform != :ios_xr
        SnmpCommunity.new(nil, 'network-operator')
      else
        SnmpCommunity.new(nil, '')
      end
    end
  end

  def test_snmpcommunity_create_group_nil
    return if platform != :nexus
    assert_raises(TypeError) do
      SnmpCommunity.new('test', nil)
    end
  end

  def test_snmpcommunity_create_name_zero_length
    return if platform != :nexus
    assert_raises(Cisco::CliError) do
      SnmpCommunity.new('', 'network-operator')
    end
  end

  def test_snmpcommunity_create_group_zero_length
    return if platform != :nexus
    assert_raises(Cisco::CliError) do
      SnmpCommunity.new('test', '')
    end
  end

  def test_snmpcommunity_create_name_too_long
    name = 'co' + 'c' * SNMP_COMMUNITY_NAME_STR
    assert_raises(Cisco::CliError) do
      if platform != :ios_xr
        SnmpCommunity.new(name, 'network-operator')
      else
        SnmpCommunity.new(name, '')
      end
    end
  end

  def test_snmpcommunity_create_group_too_long
    return if platform != :nexus
    group = 'gr' + 'g' * SNMP_GROUP_NAME_STR
    assert_raises(Cisco::CliError) do
      SnmpCommunity.new('test', group)
    end
  end

  def test_snmpcommunity_create_group_invalid
    return if platform != :nexus
    name = 'ciscotest'
    group = 'network-operator-invalid'
    assert_raises(Cisco::CliError) do
      SnmpCommunity.new(name, group)
    end
  end

  def test_snmpcommunity_create_valid
    name = 'cisco'
    group = 'network-operator'
    if platform != :ios_xr
      snmpcommunity = SnmpCommunity.new(name, group)
      assert_show_match(
        pattern: /snmp-server community\s#{name}\sgroup\s#{group}/)
    else
      snmpcommunity = SnmpCommunity.new(name, '')
      assert_show_match(
        pattern: /snmp-server community\s#{name}/)
    end
    cleanup_snmpcommunity(snmpcommunity)
  end

  def test_snmpcommunity_create_with_name_alphanumeric_char
    name = 'cisco128lab'
    group = 'network-operator'
    if platform != :ios_xr
      snmpcommunity = SnmpCommunity.new(name, group)
      assert_show_match(
        pattern: /snmp-server community\s#{name}\sgroup\s#{group}/)
    else
      snmpcommunity = SnmpCommunity.new(name, '')
      assert_show_match(
        pattern: /snmp-server community\s#{name}/)
    end
    cleanup_snmpcommunity(snmpcommunity)
  end

  def test_snmpcommunity_get_group
    return if platform != :nexus
    name = 'ciscogetgrp'
    group = 'network-operator'
    snmpcommunity = SnmpCommunity.new(name, group)
    assert_equal(snmpcommunity.group, group)
    cleanup_snmpcommunity(snmpcommunity)
  end

  def test_snmpcommunity_group_set_zero_length
    return if platform != :nexus
    name = 'ciscogroupsetcom'
    group = 'network-operator'
    snmpcommunity = SnmpCommunity.new(name, group)
    assert_raises(Cisco::CliError) do
      snmpcommunity.group = ''
    end
    cleanup_snmpcommunity(snmpcommunity)
  end

  def test_snmpcommunity_group_set_too_long
    return if platform != :nexus
    name = 'ciscogroupsetcom'
    group = 'network-operator'
    snmpcommunity = SnmpCommunity.new(name, group)
    assert_raises(Cisco::CliError) do
      snmpcommunity.group = 'group123456789c123456789c123456789c12345'
    end
    cleanup_snmpcommunity(snmpcommunity)
  end

  def test_snmpcommunity_group_set_invalid
    return if platform != :nexus
    name = 'ciscogroupsetcom'
    group = 'network-operator'
    snmpcommunity = SnmpCommunity.new(name, group)
    assert_raises(Cisco::CliError) do
      snmpcommunity.group = 'testgroup'
    end
    cleanup_snmpcommunity(snmpcommunity)
  end

  def test_snmpcommunity_group_set_valid
    return if platform != :nexus
    name = 'ciscogroupsetcom'
    group = 'network-operator'
    snmpcommunity = SnmpCommunity.new(name, group)
    # new group
    group = 'network-admin'
    snmpcommunity.group = group
    assert_show_match(
      pattern: /snmp-server community\s#{name}\sgroup\s#{group}/)
    cleanup_snmpcommunity(snmpcommunity)
  end

  def test_snmpcommunity_group_set_default
    return if platform != :nexus
    name = 'ciscogroupsetcom'
    group = 'network-operator'
    snmpcommunity = SnmpCommunity.new(name, group)
    # new group identity
    group = 'vdc-admin'
    snmpcommunity.group = group
    assert_show_match(
      pattern: /snmp-server community\s#{name}\sgroup\s#{group}/)

    # Restore group default
    group = SnmpCommunity.default_group
    snmpcommunity.group = group
    assert_show_match(
      pattern: /snmp-server community\s#{name}\sgroup\s#{group}/)

    cleanup_snmpcommunity(snmpcommunity)
  end

  def test_snmpcommunity_destroy_valid
    name = 'ciscotest'
    group = 'network-operator'
    if platform != :ios_xr
      snmpcommunity = SnmpCommunity.new(name, group)
    else
      snmpcommunity = SnmpCommunity.new(name, '')
    end
    snmpcommunity.destroy
    if platform != :ios_xr
      refute_show_match(
        pattern: /snmp-server community\s#{name}\sgroup\s#{group}/)
    else
      refute_show_match(
        pattern: /snmp-server community\s#{name}/)
    end
  end

  def test_snmpcommunity_acl_get_no_acl
    return if platform != :nexus
    name = 'cisconoaclget'
    group = 'network-operator'
    snmpcommunity = SnmpCommunity.new(name, group)
    assert_equal(snmpcommunity.acl, '')
    cleanup_snmpcommunity(snmpcommunity)
  end

  def test_snmpcommunity_acl_get
    return if platform != :nexus
    name = 'ciscoaclget'
    group = 'network-operator'
    snmpcommunity = SnmpCommunity.new(name, group)
    snmpcommunity.acl = 'ciscoacl'
    line = assert_show_match(
      pattern: /snmp-server community\s#{name}\suse-acl\s\S+/)
    acl = line.to_s.gsub(/snmp-server community\s#{name}\suse-acl\s/, '').strip
    assert_equal(snmpcommunity.acl, acl)
    cleanup_snmpcommunity(snmpcommunity)
  end

  def test_snmpcommunity_acl_set_nil
    return if platform != :nexus
    name = 'cisco'
    group = 'network-operator'
    snmpcommunity = SnmpCommunity.new(name, group)
    assert_raises(TypeError) do
      snmpcommunity.acl = nil
    end
    cleanup_snmpcommunity(snmpcommunity)
  end

  def test_snmpcommunity_acl_set_valid
    return if platform != :nexus
    name = 'ciscoadmin'
    group = 'network-admin'
    acl = 'ciscoadminacl'
    snmpcommunity = SnmpCommunity.new(name, group)
    snmpcommunity.acl = acl
    assert_show_match(
      pattern: /snmp-server community\s#{name}\suse-acl\s#{acl}/)
    cleanup_snmpcommunity(snmpcommunity)
  end

  def test_snmpcommunity_acl_set_zero_length
    return if platform != :nexus
    name = 'ciscooper'
    group = 'network-operator'
    acl = 'ciscooperacl'
    snmpcommunity = SnmpCommunity.new(name, group)
    # puts "set acl #{acl}"
    snmpcommunity.acl = acl
    assert_show_match(
      pattern: /snmp-server community\s#{name}\suse-acl\s#{acl}/)
    # remove acl
    snmpcommunity.acl = ''
    refute_show_match(
      pattern: /snmp-server community\s#{name}\suse-acl\s#{acl}/)
    cleanup_snmpcommunity(snmpcommunity)
  end

  def test_snmpcommunity_acl_set_default
    return if platform != :nexus
    name = 'cisco'
    group = 'network-operator'
    acl = 'cisco_test_acl'
    snmpcommunity = SnmpCommunity.new(name, group)
    snmpcommunity.acl = acl
    assert_show_match(
      pattern: /snmp-server community\s#{name}\suse-acl\s#{acl}/)

    # Check default_acl
    assert_equal(DEFAULT_SNMP_COMMUNITY_ACL,
                 SnmpCommunity.default_acl,
                 'Error: Snmp Community, default ACL not correct value')

    # Set acl to default
    acl = SnmpCommunity.default_acl
    snmpcommunity.acl = acl
    refute_show_match(
      pattern: /snmp-server community\s#{name}\suse-acl\s#{acl}/)
    cleanup_snmpcommunity(snmpcommunity)
  end
end
