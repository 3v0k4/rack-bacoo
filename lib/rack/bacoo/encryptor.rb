# frozen_string_literal: true

require "base64"
require "openssl"

module Rack
  module Bacoo
    class Encryptor
      DecryptionError = Class.new(StandardError)

      AUTH_TAG_LENGTH = 16
      CIPHER = "aes-256-gcm"
      SALT = "entropy comes from the password"
      SEPARATOR = "--"

      def initialize(password)
        key_len = new_cipher.key_len
        digest = OpenSSL::Digest.new("SHA256")
        # Rationale on how the key is generated: https://github.com/rails/rails/pull/6952
        @key = OpenSSL::PKCS5.pbkdf2_hmac(password, SALT, 1000, key_len, digest)
      end

      def encrypt(data)
        cipher = new_cipher
        cipher.encrypt
        cipher.key = @key
        iv = cipher.random_iv
        cipher.auth_data = ""
        encrypted_data = cipher.update(data) + cipher.final
        parts = [encrypted_data, iv, cipher.auth_tag(AUTH_TAG_LENGTH)]
        parts.map { ::Base64.strict_encode64(_1) }.join(SEPARATOR)
      end

      def decrypt(encrypted_message)
        cipher = new_cipher
        encrypted_data, iv, auth_tag = extract_parts(encrypted_message)

        # Currently the OpenSSL bindings do not raise an error if auth_tag is
        # truncated, which would allow an attacker to easily forge it:
        # https://github.com/ruby/openssl/issues/63
        raise DecryptionError, "truncated auth_tag" if auth_tag.bytesize != AUTH_TAG_LENGTH

        cipher.decrypt
        cipher.key = @key
        cipher.iv  = iv
        cipher.auth_tag = auth_tag
        cipher.auth_data = ""
        cipher.update(encrypted_data) + cipher.final
      end

      private

      # Base64 encodes with a 6-bit alphabet plus padding:
      # https://en.wikipedia.org/wiki/Base64
      def length_after_base64(length_before_base64)
        4 * (length_before_base64 / 3.0).ceil
      end

      def length_of_encoded_iv
        @length_of_encoded_iv ||= length_after_base64(new_cipher.iv_len)
      end

      def length_of_encoded_auth_tag
        @length_of_encoded_auth_tag ||= length_after_base64(AUTH_TAG_LENGTH)
      end

      def extract_parts(encrypted_message)
        parts = []
        rindex = encrypted_message.length

        parts << extract_part(encrypted_message, rindex, length_of_encoded_auth_tag)
        rindex -= SEPARATOR.length + length_of_encoded_auth_tag

        parts << extract_part(encrypted_message, rindex, length_of_encoded_iv)
        rindex -= SEPARATOR.length + length_of_encoded_iv

        parts << encrypted_message[0, rindex]

        parts.reverse!.map! { ::Base64.strict_decode64(_1) }
      end

      def extract_part(encrypted_message, rindex, length)
        index = rindex - length

        unless encrypted_message[index - SEPARATOR.length, SEPARATOR.length] == SEPARATOR
          raise DecryptionError, "missing separator"
        end

        encrypted_message[index, length]
      end

      def new_cipher
        OpenSSL::Cipher.new(CIPHER)
      end
    end
  end
end
