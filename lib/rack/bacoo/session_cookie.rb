# frozen_string_literal: true

require "bcrypt"
require "securerandom"

module Rack
  module Bacoo
    class SessionCookie
      WRONG_USERNAME = SecureRandom.hex
      WRONG_PASSWORD = BCrypt::Password.create(SecureRandom.hex, cost: 1)

      def initialize(cookie_attributes, encryptor, env)
        @cookie_attributes = cookie_attributes.dup
        @cookie_name = @cookie_attributes.delete(:cookie_name)
        @encryptor = encryptor
        @env = env
      end

      def username
        get.nil? ? WRONG_USERNAME : get.first
      end

      def password
        get.nil? ? WRONG_PASSWORD : get.last
      end

      def set(headers, username, encrypted_password)
        value = @encryptor.encrypt("#{username}:#{encrypted_password}:#{expires_at}")
        value = @cookie_attributes.merge(value: value)
        Utils.set_cookie_header!(headers, @cookie_name, value)
      end

      private

      def get
        value = Utils.parse_cookies(@env).fetch(@cookie_name, nil)
        return nil if value.nil?

        username, password, expires_at = @encryptor.decrypt(value).split(":")
        return nil if expires_at.to_i < Time.now.to_i

        [username, password]
      end

      # If a cookie has both the Max-Age and the Expires attribute, the
      # Max-Age attribute has precedence and controls the expiration date
      # of the cookie.
      # https://datatracker.ietf.org/doc/html/rfc6265#section-4.1.2.2
      def expires_at
        case @cookie_attributes
        in { max_age: max_age }
          Time.now.to_i + max_age.to_i
        in { expires: expires }
          expires.to_i
        else
          Time.now.to_i
        end
      end
    end
  end
end
