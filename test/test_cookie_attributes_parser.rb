# frozen_string_literal: true

require "test_helper"

class TestCookieAttributesParser < Minitest::Test
  def test_raises_with_unsafe_cookie_attributes
    [
      [:secure, false, "secure must be true"],
      [:secure, nil, "secure must be true"],
      [:http_only, false, "http_only must be true"],
      [:http_only, nil, "http_only must be true"],
      [:httponly, false, "httponly must be true"],
      [:httponly, nil, "httponly must be true"],
      [:same_site, nil, "same_site must be either lax or strict"],
      [:same_site, false, "same_site must be either lax or strict"],
      [:same_site, :none, "same_site must be either lax or strict"],
      [:same_site, "None", "same_site must be either lax or strict"],
      [:same_site, :None, "same_site must be either lax or strict"]
    ].each do |key, value, message|
      assert_raises(ArgumentError, message) { Rack::Bacoo::CookieAttributesParser.call(key => value) }
    end
  end

  def test_parses_cookie_attributes
    [
      [:cookie_name, "rack-bacoo", "rack-bacoo"],
      [:path, "/path", "/path"],
      [:max_age, 1, 1],
      [:secure, true, true],
      [:http_only, true, true],
      [:httponly, true, true],
      %i[same_site lax lax],
      [:same_site, "Lax", "Lax"],
      %i[same_site Lax Lax],
      [:same_site, true, true],
      %i[same_site strict strict],
      [:same_site, "Strict", "Strict"],
      %i[same_site Strict Strict]
    ].each do |key, value, expected|
      parsed = Rack::Bacoo::CookieAttributesParser.call(key => value)
      assert_equal expected, parsed.fetch(key)
    end
  end

  def test_assigns_defaults
    parsed = Rack::Bacoo::CookieAttributesParser.call({})
    assert_equal "rack-bacoo", parsed.fetch(:cookie_name)
    assert_equal "/", parsed.fetch(:path)
    assert_equal 86_400, parsed.fetch(:max_age)
    assert parsed.fetch(:secure)
    assert parsed.fetch(:http_only)
    assert_equal "Lax", parsed.fetch(:same_site)
  end
end
