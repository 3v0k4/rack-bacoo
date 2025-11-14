# frozen_string_literal: true

require "rack"

require_relative "rack/bacoo/version"
require_relative "rack/bacoo/credentials"
require_relative "rack/bacoo/authenticator"
require_relative "rack/bacoo/cookie_attributes_parser"
require_relative "rack/bacoo/encryptor"

module Rack
  module Bacoo
    class Middleware
      DEFAULTS = {
        cookie_attributes: {},
        password_cost: BCrypt::Engine.cost,
        paths: [Regexp.new(".*")],
        realm: nil
      }.freeze

      attr_accessor :realm

      def initialize(app, config)
        config = DEFAULTS.merge(config)

        @app = app
        @paths, @realm = config.fetch_values(:paths, :realm)
        @authenticator = Authenticator.new(
          cookie_attributes: CookieAttributesParser.call(config.fetch(:cookie_attributes)),
          cookie_encryptor: Encryptor.new(config.fetch(:encrypt_cookie_with)),
          password_cost: config.fetch(:password_cost),
          users: config.fetch(:users)
        )
      end

      def call(env)
        @authenticator.with_env(env) do
          actual_path = Utils.clean_path_info(Utils.unescape_path(env["PATH_INFO"]))
          return @app.call(env) if @paths.none? { _1.match? actual_path }
          @authenticator.cookie_authenticated { |credentials| return call_app(credentials, env) }
          return unauthorized unless @authenticator.basic_auth_provided?
          return bad_request unless @authenticator.valid_basic_auth?
          @authenticator.basic_authenticated { |credentials| return call_app(credentials, env) }

          unauthorized
        end
      end

      private

      def call_app(credentials, env)
        env["REMOTE_USER"] = credentials.username
        @app.call(env).tap do |_, headers, _|
          @authenticator.persist_session!(credentials, headers)
        end
      end

      def unauthorized
        [
          401,
          {
            CONTENT_TYPE => "text/plain",
            CONTENT_LENGTH => "0",
            "www-authenticate" => "Basic realm=\"#{realm}\""
          },
          []
        ]
      end

      def bad_request
        [
          400,
          {
            CONTENT_TYPE => "text/plain",
            CONTENT_LENGTH => "0"
          },
          []
        ]
      end
    end
  end
end
