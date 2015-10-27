#!/usr/bin/env ruby
#
# November 2014, Glenn F. Matthews
#
# Copyright (c) 2014-2015 Cisco and/or its affiliates.
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
#

require 'minitest/autorun'
require 'tempfile'
require_relative '../lib/cisco_node_utils/command_reference'

# TestCmdRef - Minitest for CommandReference and CmdRef classes.
class TestCmdRef < MiniTest::Test
  include Cisco

  def setup
    @input_file = Tempfile.new('test.yaml')
  end

  def teardown
    @input_file.close!
  end

  def load_file(api='', product_id='')
    CommandReference.new(api, product_id, [@input_file.path])
  end

  def write(string)
    @input_file.write(string + "\n")
    @input_file.flush
  end

  def test_load_empty_file
    # should load successfully but yield an empty hash
    reference = load_file
    assert_empty(reference)
  end

  def test_load_whitespace_only
    write('   ')
    reference = load_file
    assert_empty(reference)
  end

  def test_load_not_valid_yaml
    # The control characters embedded below are not permitted in YAML.
    write("
name\a\e\b\f:
  default_value:\vtrue")
    assert_raises(RuntimeError) { load_file }
  end

  def test_load_feature_name_no_data
    write("
name:")
    assert_raises(RuntimeError) do
      load_file
    end
  end

  def test_load_feature_name_default
    write("
name:
  default_value: true")
    reference = load_file
    assert(!reference.empty?)
    ref = reference.lookup('test', 'name')
    assert_equal(true, ref.default_value)
  end

  def test_load_duplicate_name
    write("
name:
  default_value: false
name:
  config_get: 'show feature'")
    assert_raises(RuntimeError) { load_file }
  end

  def test_load_duplicate_param
    write("
name:
  default_value: false
  default_value: true")
    assert_raises(RuntimeError) { load_file }
  end

  def test_load_unsupported_key
    write("
name:
  config_get: 'show feature'
  what_is_this: \"I don't even\"")
    assert_raises(RuntimeError) { load_file }
  end

  #   # Alphabetization of features is not enforced at this time.
  #   def test_load_features_unalphabetized
  #     write("
  # zzz:
  #   name:
  #     default_value: true
  # zzy:
  #   name:
  #     default_value: false")
  #     self.assert_raises(RuntimeError) { load_file }
  #   end

  def type_check(obj, cls)
    assert(obj.is_a?(cls), "#{obj} should be #{cls} but is #{obj.class}")
  end

  def test_load_types
    write("
name:
  default_value: true
  config_get: show hello
  config_get_token: !ruby/regexp '/hello world/'
  config_set: [ \"hello\", \"world\" ]
  test_config_get_regex: !ruby/regexp '/hello world/'
")
    reference = load_file
    ref = reference.lookup('test', 'name')
    type_check(ref.default_value, TrueClass)
    type_check(ref.config_get, String)
    type_check(ref.config_get_token, Array)
    type_check(ref.config_get_token[0], Regexp)
    type_check(ref.config_set, Array)
    type_check(ref.test_config_get_regex, Regexp)
  end

  def write_variants
    write("
name:
  default_value: 'generic'
  nxapi:
    default_value: 'NXAPI base'
    /N7K/:
      default_value: 'NXAPI N7K'
    /N9K/:
      default_value: 'NXAPI N9K'
  grpc:
    /XRv9k/:
      default_value: 'gRPC XRv9k'
    else:
      default_value: 'gRPC base'
")
  end

  def test_load_generic
    write_variants
    # Neither NXAPI nor gRPC
    reference = load_file('', '')
    assert_equal('generic', reference.lookup('test', 'name').default_value)
  end

  def test_load_n9k
    write_variants
    reference = load_file('NXAPI', 'N9K-C9396PX')
    assert_equal('NXAPI N9K', reference.lookup('test', 'name').default_value)
  end

  def test_load_n7k
    write_variants
    reference = load_file('NXAPI', 'N7K-C7010')
    assert_equal('NXAPI N7K', reference.lookup('test', 'name').default_value)
  end

  def test_load_n3k_3064
    write_variants
    reference = load_file('NXAPI', 'N3K-C3064PQ-10GE')
    assert_equal('NXAPI base', reference.lookup('test', 'name').default_value)
  end

  def test_load_grpc_xrv9k
    write_variants
    reference = load_file('gRPC', 'XRv9k')
    assert_equal('gRPC XRv9k', reference.lookup('test', 'name').default_value)
  end

  def test_load_grpc_generic
    write_variants
    reference = load_file('gRPC', '')
    assert_equal('gRPC base', reference.lookup('test', 'name').default_value)
  end
end
