# frozen_string_literal: true

require 'fluent/plugin/parser'

module Fluent
  module Plugin
    # parser
    # prometheus exposition format - text-based
    # https://prometheus.io/docs/instrumenting/exposition_formats/
    class PrometheusTextParser < Parser
      Fluent::Plugin.register_parser('prometheus_text', self)

      DEFAULT_TIME_FORMAT = '%Q'
      DEFAULT_DELIMITER = "\n"
      DEFAULT_LABEL_PREFIX = ''

      desc 'Delimiter used to split prometheus entries'
      config_param :delimiter, :string, default: DEFAULT_DELIMITER
      desc 'Prefix for labels'
      config_param :label_prefix, :string, default: DEFAULT_LABEL_PREFIX
      desc 'Add type information in the generated metric'
      config_param :add_type, :bool, default: true

      EMPTY_RE = /^[[:space:]]*$/.freeze
      COMMENT_RE = /^#/.freeze
      HELP_RE = /^#\sHELP\s(?<metric_name>\w+)\s(?<metric_docstring>.*)$/.freeze
      TYPE_RE = /^#\sTYPE\s(?<metric_name>\w+)\s(?<metric_type>\w+)/.freeze
      METRIC_RE = /^(?<metric_name>\w+)
                    (:?\{(?<labels>.*?)\})?\s*
                    (?<metric_value>[-\dEe.]+|Nan|[+-]Inf)
                    (?:\s(?<timestamp>-?\d+))?$/x.freeze
      LABEL_RE = /(?:\b(\w+)="(.*?)(?<!\\)"(?:,?|\b))/.freeze

      def configure(conf)
        super

        raise Fluent::ConfigError, 'delimiter must not be empty.' if !delimiter || delimiter.empty?

        @time_parser = Fluent::TimeParser.new(DEFAULT_TIME_FORMAT)
      end

      def parse(text)
        types_store = {}

        text.each_line(delimiter, chomp: true) do |entry|
          case entry
          when empty_re
            # skip blank entry
          when help_re
            # skip docstring
          when type_re
            types_store[Regexp.last_match('metric_name')] = Regexp.last_match('metric_type')
          when comment_re
            # skip comment
          when metric_re
            time = generate_metric_timestamp(Regexp.last_match('timestamp'))
            record = generate_metric_record(
              Regexp.last_match('metric_name'),
              Regexp.last_match('metric_value'),
              Regexp.last_match('labels')
            )
            if add_type
              if types_store.key?(record['metric_name'])
                record['metric_type'] = types_store[record['metric_name']]
              else
                warn("missing metric type for #{record['metric_name']}")
              end
            end
            yield time, record
          else
            error("skip unsupported prometheus entry: #{record}")
          end
        end
      end

      private

      attr_reader :time_parser

      def empty_re
        @empty_re ||= Regexp.compile(EMPTY_RE)
      end

      def help_re
        @help_re ||= Regexp.compile(HELP_RE)
      end

      def type_re
        @type_re ||= Regexp.compile(TYPE_RE)
      end

      def comment_re
        @comment_re ||= Regexp.compile(COMMENT_RE)
      end

      def metric_re
        @metric_re ||= Regexp.compile(METRIC_RE)
      end

      def label_re
        @label_re ||= Regexp.compile(LABEL_RE)
      end

      def generate_metric_timestamp(raw_timestamp)
        return if !raw_timestamp || raw_timestamp.empty?

        time_parser.parse(raw_timestamp)
      end

      def generate_metric_record(metric_name, metric_value, labels = nil)
        generate_metric_labels(labels).update(
          { 'metric_name' => metric_name,
            'metric_value' => convert_metric_value(metric_value) }
        )
      end

      def generate_metric_labels(labels)
        return {} unless labels

        record = {}
        labels.scan(label_re).each do |label_block|
          record["#{label_prefix}#{label_block[0]}"] = label_block[1]
        end
        record
      end

      def convert_metric_value(value)
        case value
        when 'NaN'
          Float::NAN
        when '+Inf'
          Float::INFINITY
        when '-Inf'
          -Float::INFINITY
        else
          value.to_f
        end
      end

      def error(message)
        return unless log

        log.error(message)
      end

      def warn(message)
        return unless log

        log.warn(message)
      end
    end
  end
end
