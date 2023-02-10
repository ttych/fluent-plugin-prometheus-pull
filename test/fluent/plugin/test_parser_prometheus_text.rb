# frozen_string_literal: true

require 'helper'
require 'fluent/plugin/parser_prometheus_text'

class PrometheusTextParserTest < Test::Unit::TestCase
  setup do
    Fluent::Test.setup
  end

  sub_test_case 'parser params' do
    test 'default params' do
      driver = create_driver

      assert_equal Fluent::Plugin::PrometheusTextParser::DEFAULT_DELIMITER, driver.instance.delimiter
      assert_equal "\n", driver.instance.delimiter
      assert_equal Fluent::Plugin::PrometheusTextParser::DEFAULT_LABEL_PREFIX, driver.instance.label_prefix
      assert_equal '', driver.instance.label_prefix
      assert_equal true, driver.instance.add_type
    end

    test 'delimiter must not be empty' do
      config = %(
        delimiter ''
      )
      assert_raise(Fluent::ConfigError) { create_driver(config) }
    end
  end

  sub_test_case 'parsing records' do
    test 'parse minimalistic line' do
      prometheus_text = <<~METRICS_END
        # Minimalistic line:
        metric_without_timestamp_and_labels 12.47
      METRICS_END
      expected_metric = [nil,
                         { 'metric_name' => 'metric_without_timestamp_and_labels',
                           'metric_value' => 12.47 }]

      driver = create_driver
      record_count = 0
      driver.instance.parse(prometheus_text) do |time, record|
        assert_equal(expected_metric[0], time ? time.to_time : time)
        assert_equal(expected_metric[1], record)
        record_count += 1
      end
      assert_equal 1, record_count
    end

    test 'parse metric with timestamp' do
      prometheus_text = <<~METRICS_END
        # HELP http_requests_total The total number of HTTP requests.
        # TYPE http_requests_total counter
        http_requests_total{method="post",code="200"} 1027 1395066363001
        http_requests_total{method="post",code="400"}    3 1395066363002
      METRICS_END
      expected_metrics = [
        [Time.strptime('1395066363001', '%Q'),
         { 'metric_name' => 'http_requests_total',
           'metric_value' => 1027.0,
           'metric_type' => 'counter',
           'method' => 'post',
           'code' => '200' }],
        [Time.strptime('1395066363002', '%Q'),
         { 'metric_name' => 'http_requests_total',
           'metric_value' => 3.0,
           'metric_type' => 'counter',
           'method' => 'post',
           'code' => '400' }]
      ]

      driver = create_driver
      record_count = 0
      driver.instance.parse(prometheus_text) do |time, record|
        assert_equal(expected_metrics[record_count][0], time.to_time)
        assert_equal(expected_metrics[record_count][1], record)
        record_count += 1
      end
      assert_equal 2, record_count
    end

    test 'parse metric with labels' do
      prometheus_text = <<~'METRICS_END'
        msdos_file_access_time_seconds{path="C:\\DIR\\FILE.TXT",error="Cannot find file:\n\"FILE.TXT\""} 1.458255915e9
      METRICS_END
      expected_metric = [nil,
                         { 'metric_name' => 'msdos_file_access_time_seconds',
                           'metric_value' => 1_458_255_915.0,
                           'path' => 'C:\\\\DIR\\\\FILE.TXT',
                           'error' => 'Cannot find file:\\n\\"FILE.TXT\\"' }]

      driver = create_driver
      record_count = 0
      driver.instance.parse(prometheus_text) do |time, record|
        assert_equal(expected_metric[0], time ? time.to_time : time)
        assert_equal(expected_metric[1], record)
        record_count += 1
      end
      assert_equal 1, record_count
    end

    test 'parse metric with labels and label_prefix' do
      prometheus_text = <<~'METRICS_END'
        any_metric{criticity="high",availability="high"} 1.234
      METRICS_END
      expected_metric = [nil,
                         { 'metric_name' => 'any_metric',
                           'metric_value' => 1.234,
                           'tags_criticity' => 'high',
                           'tags_availability' => 'high' }]

      config = %(
        label_prefix tags_
      )
      driver = create_driver(config)
      record_count = 0
      driver.instance.parse(prometheus_text) do |time, record|
        assert_equal(expected_metric[0], time ? time.to_time : time)
        assert_equal(expected_metric[1], record)
        record_count += 1
      end
      assert_equal 1, record_count
    end

    test 'parse weird metric from before the epoch' do
      prometheus_text = <<~METRICS_END
        # A weird metric from before the epoch:
        something_weird{problem="division by zero"} +Inf -3982045
      METRICS_END
      expected_metric = [Time.strptime('-3982045', '%Q'),
                         { 'metric_name' => 'something_weird',
                           'metric_value' => Float::INFINITY,
                           'problem' => 'division by zero' }]

      driver = create_driver
      record_count = 0
      driver.instance.parse(prometheus_text) do |time, record|
        assert_equal(expected_metric[0], time ? time.to_time : time)
        assert_equal(expected_metric[1], record)
        record_count += 1
      end
      assert_equal 1, record_count
    end

    test 'parse NaN value' do
      prometheus_text = <<~METRICS_END
        product_used_bytes{instance="",name="success",id="def-567",destination="End",} NaN
      METRICS_END

      expected_metric = [nil,
                         { 'metric_name' => 'product_used_bytes',
                           'metric_value' => Float::NAN,
                           'instance' => '',
                           'name' => 'success',
                           'id' => 'def-567',
                           'destination' => 'End' }]

      driver = create_driver
      record_count = 0
      driver.instance.parse(prometheus_text) do |time, record|
        assert_equal(expected_metric[0], time ? time.to_time : time)
        assert_equal(expected_metric[1], record)
        record_count += 1
      end
      assert_equal 1, record_count
    end
  end

  private

  CONFIG = %()

  def create_driver(conf = CONFIG)
    Fluent::Test::Driver::Parser.new(
      Fluent::Plugin::PrometheusTextParser
    ).configure(conf)
  end
end
