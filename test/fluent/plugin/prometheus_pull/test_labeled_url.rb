# frozen_string_literal: true

require 'helper'

class LabeledUrlTest < Test::Unit::TestCase
  test 'should extract url when no label' do
    url = 'http://test.local/metrics/'
    labeled_url = Fluent::Plugin::PrometheusPull::LabeledUrl.parse_labeled_url(url)

    assert_equal 'http://test.local/metrics/', labeled_url.url
    assert_equal nil, labeled_url.label
  end

  test 'should extract url when empty label' do
    url = '@@http://test2.local/metrics/'
    labeled_url = Fluent::Plugin::PrometheusPull::LabeledUrl.parse_labeled_url(url)

    assert_equal 'http://test2.local/metrics/', labeled_url.url
    assert_equal '', labeled_url.label
  end

  test 'should extract url and label' do
    url = '@test-label@http://test3.local/metrics/'
    labeled_url = Fluent::Plugin::PrometheusPull::LabeledUrl.parse_labeled_url(url)

    assert_equal 'http://test3.local/metrics/', labeled_url.url
    assert_equal 'test-label', labeled_url.label
  end
end
