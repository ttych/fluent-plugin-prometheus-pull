# frozen_string_literal: true

require 'helper'
require 'fluent/plugin/in_prometheus_pull'

class PrometheusPullInputTest < Test::Unit::TestCase
  setup do
    Fluent::Test.setup
  end

  sub_test_case 'default parser' do
    test 'failure' do
    end
  end

  private

  CONFIG = %()

  def create_driver(conf = CONFIG)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::PrometheusPullInput).configure(conf)
  end
end
