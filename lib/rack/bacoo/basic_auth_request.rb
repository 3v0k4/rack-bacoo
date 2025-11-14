# frozen_string_literal: true

module Rack
  module Bacoo
    class BasicAuthRequest < Rack::Auth::AbstractRequest
      def valid_basic_auth?
        scheme == "basic" && credentials.length == 2
      end

      def username
        credentials.first
      end

      def password
        credentials.last
      end

      private

      def credentials
        @credentials ||= params.unpack1("m").split(":", 2)
      end
    end
  end
end
