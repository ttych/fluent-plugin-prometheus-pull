# frozen_string_literal: true

require 'helper'
require 'fluent/plugin/in_prometheus_pull'

class PrometheusPullInputTest < Test::Unit::TestCase
  setup do
    Fluent::Test.setup
  end

  sub_test_case 'configuration' do
    test 'event_url_key default value' do
      driver = create_driver
      input = driver.instance

      assert_equal nil, input.event_url_key
    end

    test 'event_url_key injected value' do
      conf = %(
        #{CONFIG}
        event_url_key tag_url
      )

      driver = create_driver(conf)
      input = driver.instance

      assert_equal 'tag_url', input.event_url_key
    end
  end

  sub_test_case 'default parser' do
    test 'defaults' do
    end
  end

  sub_test_case 'pull' do
    test 'pull with event_url_key' do
      conf = %(
        #{CONFIG}
        urls  http://localhost:12345
        event_url_key tag_url
      )

      driver = create_driver(conf)
      input = driver.instance

      fake_raw_metrics = 'http_requests_total{method="post",code="200"} 1027 1395066363001'

      input.stubs(:fetch).returns(fake_raw_metrics)
      input.pull
      events = driver.events

      first_event = events.first
      assert_equal 'test_tag', first_event[0]
      assert_equal 'http://localhost:12345', first_event[2]['tag_url']
    end
  end

  private

  CONFIG = %(
    tag test_tag
    interval 60
  )

  def create_driver(conf = CONFIG)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::PrometheusPullInput).configure(conf)
  end
end
