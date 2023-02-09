# frozen_string_literal: true

#
# Copyright 2023- Thomas Tych
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

require 'net/http'
require 'uri'

require 'fluent/plugin/input'

module Fluent
  module Plugin
    # input / source
    # pull prometheus http endpoint
    class PrometheusPullInput < Fluent::Plugin::Input
      Fluent::Plugin.register_input('prometheus_pull', self)

      helpers :timer, :parser, :compat_parameters

      desc 'The tag of the event'
      config_param :tag, :string
      desc 'The url of monitoring target'
      config_param :urls, :array, default: [], value_type: :string

      desc 'The user agent for the pull request'
      config_param :agent, :string, default: 'fluent-plugin-prometheus-pull'
      desc 'The http verb for the pull request'
      config_param :http_method, :enum, list: %i[get], default: :get

      desc 'Polling interval'
      config_param :interval, :time
      desc 'Polling timeout'
      config_param :timeout, :time, default: 15

      desc 'Basic auth user'
      config_param :user, :string, default: nil
      desc 'Basic auth password'
      config_param :password, :string, default: nil, secret: true

      # config_section :header, param_name: :headers, multi: true do
      #   desc 'Header name'
      #   config_param :name, :string
      #   desc 'Header value'
      #   config_param :value, :string
      # end

      desc 'Verify SSL'
      config_param :verify_ssl, :bool, default: true
      desc 'CA path'
      config_param :ca_path, :string, default: nil
      desc 'CA file path'
      config_param :ca_file, :string, default: nil

      def configure(conf)
        compat_parameters_convert(conf, :parser)

        parser_config = conf.elements('parse').first
        # raise Fluent::ConfigError, '<parse> section is required.' unless parser_config
        parser_config ||= Fluent::Config::Element.new('parse', '', [], { '@type' => 'prometheus_text' })

        super

        @parser = parser_create(conf: parser_config)
      end

      def start
        super

        timer_execute(:in_prometheus_pull, @interval, &method(:pull))
      end

      def pull
        urls.each do |url|
          time = Fluent::EventTime.now
          raw_metrics = fetch(url)
          parser.parse(raw_metrics) do |_time, record|
            router.emit(tag, time, record)
          rescue StandardError => e
            error("error #{e}, while emitting #{record}")
          end
        end
      end

      private

      attr_reader :parser

      def http(uri)
        options = {
          ssl_timeout: timeout,
          open_timeout: timeout,
          read_timeout: timeout
        }
        options[:ca_path] = ca_path if ca_path
        options[:ca_file] = ca_file if ca_file
        options[:verify_mode] = verify_ssl ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
        options[:use_ssl] = uri.scheme == 'https'

        Net::HTTP.start(uri.host, uri.port, **options) do |http|
          yield(http, uri)
        end
      end

      def request(uri)
        request_class = Module.const_get("Net::HTTP::#{http_method.capitalize}")
        req = request_class.new(uri.path)
        req.basic_auth(user, password) if user && password
        req.add_field('User-Agent', agent)
        req
      end

      def fetch(url, redirect_limit = 5)
        raise 'Max number of redirects reached' if redirect_limit <= 0

        uri = URI.parse(url)
        http(uri) do |http, uri|
          req = request(uri)
          response = http.request(req)

          case response
          when Net::HTTPSuccess
            response.body
          when Net::HTTPRedirection
            fetch(response['location'], redirect_limit - 1)
          else
            error(response.value)
          end
        end
      rescue StandardError => e
        error(e)
      end

      def error(message)
        return unless log

        log.error(message)
      end
    end
  end
end
