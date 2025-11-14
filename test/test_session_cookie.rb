# frozen_string_literal: true

require "test_helper"

class TestSessionCookie < Minitest::Test
  def test_set_with_max_age
    with(Time, :now, Time.now) do |now|
      set_cookie = set({ cookie_name: "name", max_age: 10 })
      _username, _password, expires_at = set_cookie["name"].split(":")

      assert_equal "10", set_cookie["max-age"]
      assert_nil set_cookie["expires"]
      assert_equal (now + 10).to_i.to_s, expires_at
    end
  end

  def test_set_with_expires
    require "time"

    with(Time, :now, Time.now) do |now|
      set_cookie = set({ cookie_name: "name", expires: now + 10 })
      _username, _password, expires_at = set_cookie["name"].split(":")

      assert_nil set_cookie["max-age"]
      assert_equal (now + 10).httpdate, set_cookie["expires"]
      assert_equal (now + 10).to_i.to_s, expires_at
    end
  end

  def test_set_with_no_expiration
    with(Time, :now, Time.now) do |now|
      set_cookie = set({ cookie_name: "name" })
      _username, _password, expires_at = set_cookie["name"].split(":")

      assert_nil set_cookie["max-age"]
      assert_nil set_cookie["expires"]
      assert_equal now.to_i.to_s, expires_at
    end
  end

  def set(cookie_attributes)
    encryptor = Class.new do
      def encrypt(value)
        value
      end
    end

    session_cookie = Rack::Bacoo::SessionCookie.new(cookie_attributes, encryptor.new, nil)
    headers = {}
    session_cookie.set(headers, "username", "password")
    Rack::Utils.parse_cookies_header(headers["set-cookie"])
  end
end
