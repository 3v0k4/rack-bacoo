# frozen_string_literal: true

require "bcrypt"
require "securerandom"

module Rack
  module Bacoo
    class Credentials
      WRONG_USER = [SecureRandom.hex, SecureRandom.hex].freeze

      attr_reader :username, :password

      def initialize(password_cost, users)
        @password_cost = password_cost
        @users = users
      end

      def basic_authenticated?(session)
        @username = session.username
        @password = BCrypt::Password.create(session.password, cost: @password_cost)
        authenticated?(@username, @password)
      end

      def cookie_authenticated?(session)
        @username = session.username
        @password = session.password
        authenticated?(@username, BCrypt::Password.new(@password))
      end

      private

      def authenticated?(username, encrypted_password)
        valid_password = WRONG_USER[1]

        @users.each do |u, p|
          valid_password = p if Rack::Utils.secure_compare(u, username)
        end

        encrypted_password == valid_password
      end
    end
  end
end
