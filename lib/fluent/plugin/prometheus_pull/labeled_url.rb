# frozen_string_literal: true

module Fluent
  module Plugin
    module PrometheusPull
      class LabeledUrl
        LABELED_URL_RE = /^(?:@(?<label>[^@]*)@)?(?<url>.*)$/.freeze

        attr_reader :url, :label

        def initialize(url:, label: nil)
          @url = url
          @label = label
        end

        def to_s
          url
        end

        def self.parse_labeled_url(url)
          match_data = LABELED_URL_RE.match(url)

          raise Fluent::ConfigError, "unable to use url '#{url}'" unless match_data

          new(url: match_data[:url],
              label: match_data[:label])
        end
      end
    end
  end
end
