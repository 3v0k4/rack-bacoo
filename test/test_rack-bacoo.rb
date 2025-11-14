# frozen_string_literal: true

require "test_helper"
require "securerandom"

class TestRackBacoo < Minitest::Test
  REALM = "Bacoo"
  CONFIG = {
    encrypt_cookie_with: SecureRandom.hex,
    password_cost: BCrypt::Engine::MIN_COST,
    users: [["Riccardo", "Password"]]
  }.freeze

  def unprotected_app
    Rack::Lint.new ->(env) do
      [200, { "content-type" => "text/plain" }, ["Hi #{env["REMOTE_USER"]}"]]
    end
  end

  def protected_app
    app = Rack::Bacoo::Middleware.new(unprotected_app, CONFIG)
    app.realm = REALM
    app
  end

  def request_with_basic_auth(username, password, &block)
    request "HTTP_AUTHORIZATION" => "Basic #{["#{username}:#{password}"].pack("m*")}", &block
  end

  def request(headers = {})
    yield Rack::MockRequest.new(protected_app).get("/", headers)
  end

  def assert_basic_auth_challenge(response)
    assert_predicate response, :client_error?
    assert_equal 401, response.status
    assert_includes response, "www-authenticate"
    assert_match(/Basic realm="#{Regexp.escape(REALM)}"/, response.headers["www-authenticate"])
    assert_predicate response.body, :empty?
  end

  def test_challenge_correctly_when_no_credentials_are_specified
    request do |response|
      assert_basic_auth_challenge response
    end
  end

  def test_rechallenge_if_incorrect_credentials_are_specified
    request_with_basic_auth "wrong", "pass" do |response|
      assert_basic_auth_challenge response
    end
  end

  def test_return_application_output_if_correct_credentials_are_specified
    request_with_basic_auth "Riccardo", "Password" do |response|
      assert_equal 200, response.status
      assert_equal "Hi Riccardo", response.body.to_s
    end
  end

  def test_challenges_only_the_correct_paths
    config = CONFIG.merge(paths: [Regexp.new("^/$")])
    protected_app = Rack::Bacoo::Middleware.new(unprotected_app, config)
    protected_app.realm = REALM
    request = Rack::MockRequest.new(protected_app)

    response = request.get("/", {})
    assert_basic_auth_challenge response

    response = request.get("/up", {})
    assert_equal 200, response.status
  end

  def test_sets_the_cookie_if_correct_credentials_are_specified
    request_with_basic_auth "Riccardo", "Password" do |response|
      assert_equal 200, response.status
      assert_equal "Hi Riccardo", response.body.to_s

      set_cookie = Rack::Utils.parse_cookies_header(response.headers["set-cookie"])
      cookie_value = set_cookie.fetch("rack-bacoo")

      assert cookie_value
      assert_includes set_cookie.keys, "secure"
      assert_includes set_cookie.keys, "httponly"
      assert_equal "lax", set_cookie.fetch("samesite")
      assert_equal "/", set_cookie.fetch("path")
      assert_equal "86400", set_cookie.fetch("max-age")

      cookie = "rack-bacoo=#{Rack::Utils.escape(cookie_value)}"
      request "HTTP_COOKIE" => cookie do |response|
        assert_equal 200, response.status
        assert_equal "Hi Riccardo", response.body.to_s

        set_cookie = Rack::Utils.parse_cookies_header(response.headers["set-cookie"])
        cookie_value = set_cookie.fetch("rack-bacoo")

        assert cookie_value
        assert_includes set_cookie.keys, "secure"
        assert_includes set_cookie.keys, "httponly"
        assert_equal "lax", set_cookie.fetch("samesite")
        assert_equal "/", set_cookie.fetch("path")
        assert_equal "86400", set_cookie.fetch("max-age")
      end
    end
  end

  def test_sets_the_cookie_using_cookie_attributes
    require "time"

    expires = Time.now + 1
    cookie_attributes = {
      cookie_name: "Biscuit",
      max_age: 1,
      path: "/test/path",
      same_site: "Strict",
      domain: "example.com",
      expires: expires
    }

    config = CONFIG.merge(cookie_attributes: cookie_attributes)
    protected_app = Rack::Bacoo::Middleware.new(unprotected_app, config)
    protected_app.realm = REALM
    request = Rack::MockRequest.new(protected_app)

    headers = { "HTTP_AUTHORIZATION" => "Basic #{["Riccardo:Password"].pack("m*")}" }
    response = request.get("/", headers)

    assert_equal 200, response.status
    assert_equal "Hi Riccardo", response.body.to_s

    set_cookie = Rack::Utils.parse_cookies_header(response.headers["set-cookie"])
    cookie_value = set_cookie.fetch("Biscuit")

    assert cookie_value
    assert_equal "/test/path", set_cookie.fetch("path")
    assert_equal "strict", set_cookie.fetch("samesite")
    assert_equal "example.com", set_cookie.fetch("domain")
    assert_equal "1", set_cookie.fetch("max-age")
    assert_equal expires.httpdate, set_cookie.fetch("expires")
  end

  def test_expired_cookie_is_ignored
    request_with_basic_auth "Riccardo", "Password" do |response|
      assert_equal 200, response.status
      assert_equal "Hi Riccardo", response.body.to_s

      set_cookie = Rack::Utils.parse_cookies_header(response.headers["set-cookie"])
      cookie_value = set_cookie.fetch("rack-bacoo")
      cookie = "rack-bacoo=#{Rack::Utils.escape(cookie_value)}"

      with(Time, :now, Time.now + 24 * 60 * 60 + 1) do
        request "HTTP_COOKIE" => cookie do |response|
          assert_basic_auth_challenge response
        end
      end
    end
  end

  def test_return_400_bad_request_if_different_auth_scheme_used
    request "HTTP_AUTHORIZATION" => "Digest params" do |response|
      assert_predicate response, :client_error?
      assert_equal 400, response.status
      refute_includes response, "www-authenticate"
    end
  end

  def test_return_400_bad_request_for_a_malformed_authorization_header
    request "HTTP_AUTHORIZATION" => "" do |response|
      assert_predicate response, :client_error?
      assert_equal 400, response.status
      refute_includes response, "www-authenticate"
    end
  end

  def test_return_401_bad_request_for_a_nil_authorization_header
    request "HTTP_AUTHORIZATION" => nil do |response|
      assert_predicate response, :client_error?
      assert_equal 401, response.status
    end
  end

  def test_return_400_bad_request_for_a_authorization_header_with_only_username
    request "HTTP_AUTHORIZATION" => "Basic #{["foo"].pack("m*")}" do |response|
      assert_predicate response, :client_error?
      assert_equal 400, response.status
      refute_includes response, "www-authenticate"
    end
  end

  def test_takes_realm_as_optional_constructor_arg
    config = CONFIG.merge(realm: REALM)
    app = Rack::Bacoo::Middleware.new(unprotected_app, config)

    assert_equal REALM, app.realm
  end
end
