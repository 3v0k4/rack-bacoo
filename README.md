# Rack::Bacoo

<div align="center">
  <img width="200" width="200" src=".github/images/rack-bacoo.svg" />
</div>

<br />

Rack::Bacoo combines HTTP Basic Authentication with a session cookie so that you don't have to input username and password on each visit.

The session cookie is encrypted (aes-256-gcm), and the password inside is hashed (bcrypt).

## Installation

Add `rack-bacoo` to the Gemfile:

```bash
bundle add rack-bacoo
```

## Usage

With Rails:

```ruby
config = {
  encrypt_cookie_with: Rails.application.secret_key_base,
  paths: [ Regexp.new("^(?!/up$)") ], # All paths but /up
  users: [ [ "username", "password" ] ]
}

config[:password_cost] = BCrypt::Engine::MIN_COST if Rails.env.test?

Rails.application.config.middleware.insert_before 0, Rack::Bacoo::Middleware, config
```

For other web frameworks, check out their documentation on how to `use` a Rack middleware.

## Configuration

You are required to configure only `users` and `encrypt_cookie_with`. But you have more fine-grained control if you want:

| Key                   | Default               | Description |
| --------------------- | --------------------- | ----------- |
| `encrypt_cookie_with` | Required              | Secret used to encrypt the session cookie (e.g., `SecureRandom.hex(64)`) |
| `users`               | Required              | Who can authenticate (e.g., `[ [ "username", "password" ] ]`) |
| `cookie_attributes`   | `{}`                  | See table below |
| `password_cost`       | `BCrypt::Engine.cost` | [Amount of work required to hash the password](https://github.com/bcrypt-ruby/bcrypt-ruby?tab=readme-ov-file#cost-factors) |
| `paths`               | `[ Regep.new(".*") ]` | Paths that require authentication |
| `realm`               | `nil`                 | [HTTP Authentication realm](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Authentication#www-authenticate_and_proxy-authenticate_headers) |

`cookie_attributes` must be a hash of [HTTP cookie attributes](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Cookies):

| Key           | Default          | Type |
| ------------- | ---------------- | ---------------- |
| `cookie_name` | `"rack-bacoo"`     | String           |
| `max_age`     | `24*60*60` (24h) | Number or String |
| `path`        | `"/"`            | String           |
| `same_site`   | `"Lax"`          | String           |
| `domain`      |                  | String           |
| `expires`     |                  | Time             |

Behind the curtains, `cookie_attributes` are passed to [`Rack::Utils.set_cookie_header`](https://www.rubydoc.info/gems/rack/Rack/Utils#set_cookie_header-class_method), but `secure` and `http_only` (or `httponly`) are ignored and set to `true` for security reasons.

## Security

The defaults should be secure enough for most applications.

Rack::Bacoo works as follows:

1. If the requested path matches any of the `paths`, Rack::Bacoo
1. tries cookie authentication
    1. checks if `cookie_name` is in the request and
    1. decrypts the cookie with `encrypt_cookie_with` to obtain the username & hashed password
    1. looks for a match with any `users` by comparing in constant time `cookie.username == user.username` and `cookie.hashed_password == hash(user.password)`
1. tries HTTP Basic Authentication
    1. looks for a match with any `users` by comparing in constant time `basic.username == user.username` and `basic.password == user.password`
1. sets the encrypted session cookie (aes-256-gcm) with the authenticated username & hashed password (bcrypt)

To enforce security, Rack::Bacoo takes care of the following things:

- The cookie is `Secure`: only sent via HTTPS (encrypted)
- The cookie is `HttpOnly`: cannot be accessed by JavaScript
- The cookie can only be configured as `SameSite=Lax` (default) or `SameSite=Strict`: minimizes cross-site requests
- To mitigate cookie-theft the cookie is set to expire after 24 hours by default (and expiration is embedded in the cookie value to prevent use-after-expiration)
    - You may want to shorten the expiration or use a session cookie by making `max_age` and `expire` falsy (though, some browsers still persist session cookies on disk to enable session restoring)

Make sure you always use POST requests when changing data and include CSRF tokens in your web application:

> In addition, sites that use HTTP Basic Auth are particularly vulnerable to Cross-Site Request Forgery (CSRF) attacks because the user credentials are sent in all requests regardless of origin (this differs cookie-based credential mechanisms, because cookies are commonly blocked in cross site requests). Sites should always use the POST requests when changing data, and include CSRF tokens.
>
> https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Authentication#security_of_basic_authentication

References:
- [HTTP Authentication](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Authentication)
- [HTTP Cookies](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Cookies)
- [`openssl`](https://ruby.github.io/openssl/OpenSSL.html)
- [`bcrypt-ruby`](https://github.com/bcrypt-ruby/bcrypt-ruby)

## Development

After checking out the repo, run `bin/setup` to install the dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/3v0k4/rack-bacoo).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
