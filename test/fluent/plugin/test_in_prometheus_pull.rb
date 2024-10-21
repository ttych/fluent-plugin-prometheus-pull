# frozen_string_literal: true

require 'helper'
require 'fluent/plugin/in_prometheus_pull'

class PrometheusPullInputTest < Test::Unit::TestCase
  setup do
    Fluent::Test.setup
  end

  sub_test_case 'configuration' do
    test 'with standard url' do
      conf = %(
        #{CONFIG}
        urls http://test.local/metrics/,http://test2.local/metrics/
      )

      driver = create_driver(conf)
      input = driver.instance

      assert_equal ['http://test.local/metrics/', 'http://test2.local/metrics/'], input.urls
      assert_equal ['http://test.local/metrics/', 'http://test2.local/metrics/'], input.labeled_urls.map(&:url)
      assert_equal [nil, nil], input.labeled_urls.map(&:label)
    end

    test 'with labeled url' do
      conf = %(
        #{CONFIG}
        urls @test_label@http://test.local/metrics/,@test2_label@http://test2.local/metrics/
      )

      driver = create_driver(conf)
      input = driver.instance

      assert_equal ['http://test.local/metrics/', 'http://test2.local/metrics/'], input.labeled_urls.map(&:url)
      assert_equal %w[test_label test2_label], input.labeled_urls.map(&:label)
    end

    test 'with empty labeled url' do
      conf = %(
        #{CONFIG}
        urls @@http://test.local/metrics/,@@http://test2.local/metrics/
      )

      driver = create_driver(conf)
      input = driver.instance

      assert_equal ['http://test.local/metrics/', 'http://test2.local/metrics/'], input.labeled_urls.map(&:url)
      assert_equal ['', ''], input.labeled_urls.map(&:label)
    end

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

    test 'event_url_label_key default value' do
      driver = create_driver
      input = driver.instance

      assert_equal nil, input.event_url_label_key
    end

    test 'event_url_label_key injected value' do
      conf = %(
        #{CONFIG}
        event_url_label_key tag_label
      )

      driver = create_driver(conf)
      input = driver.instance

      assert_equal 'tag_label', input.event_url_label_key
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

      assert_equal 1, events.size
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
