# frozen_string_literal: true

require_relative "basic_auth_request"
require_relative "session_cookie"

module Rack
  module Bacoo
    class Authenticator
      def initialize(cookie_attributes:, cookie_encryptor:, password_cost:, users:)
        @cookie_attributes = cookie_attributes
        @cookie_encryptor = cookie_encryptor
        @password_cost = password_cost
        @users = users
      end

      def with_env(env)
        @env = env
        @basic_auth_request = BasicAuthRequest.new(env)
        @session_cookie = SessionCookie.new(@cookie_attributes, @cookie_encryptor, env)
        @credentials = Credentials.new(@password_cost, @users)
        yield
      end

      def basic_auth_provided?
        @basic_auth_request.provided?
      end

      def valid_basic_auth?
        @basic_auth_request.valid_basic_auth?
      end

      def basic_authenticated
        return unless @credentials.basic_authenticated?(@basic_auth_request)

        yield @credentials
      end

      def cookie_authenticated
        return unless @credentials.cookie_authenticated?(@session_cookie)

        yield @credentials
      end

      def persist_session!(credentials, headers)
        @session_cookie.set(headers, credentials.username, credentials.password)
      end
    end
  end
end
