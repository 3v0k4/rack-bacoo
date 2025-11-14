# frozen_string_literal: true

module Rack
  module Bacoo
    class CookieAttributesParser
      DEFAULTS = {
        cookie_name: "rack-bacoo",
        path: "/",
        max_age: 24 * 60 * 60, # 24 hours
        secure: true,
        http_only: true,
        same_site: "Lax"
      }.freeze

      def self.call(cookie_attributes)
        cookie_attributes.each do |pair|
          case pair
          in [:secure, nil] | [:secure, false]
            raise ArgumentError, "secure must be true"
          in [:http_only, nil] | [:http_only, false]
            raise ArgumentError, "http_only must be true"
          in [:httponly, nil] | [:httponly, false]
            raise ArgumentError, "httponly must be true"
          in [:same_site, nil] | [:same_site, false]
            raise ArgumentError, "same_site must be either lax or strict"
          in [:same_site, val] if val.to_s.downcase == "none"
            raise ArgumentError, "same_site must be either lax or strict"
          else
          end
        end

        DEFAULTS.merge(cookie_attributes)
      end
    end
  end
end
