# frozen_string_literal: true

require "test_helper"
require "securerandom"

class TestEncryptor < Minitest::Test
  def test_encrypts_and_decrypts
    encryptor = Rack::Bacoo::Encryptor.new(SecureRandom.hex)
    message = "message"

    assert_equal message, encryptor.decrypt(encryptor.encrypt(message))
  end

  def test_evil
    secret = SecureRandom.hex
    encryptor = Rack::Bacoo::Encryptor.new(secret)
    encrypted = encryptor.encrypt("message")
    evil_encryptor = EvilEncryptor.new(secret)

    assert_raises(Rack::Bacoo::Encryptor::DecryptionError) do
      evil_encryptor.decrypt(encrypted)
    end
  end
end

class EvilEncryptor < Rack::Bacoo::Encryptor
  def decrypt(message)
    auth_tag_length = AUTH_TAG_LENGTH
    self.class.superclass.send(:remove_const, :AUTH_TAG_LENGTH)
    self.class.superclass.const_set(:AUTH_TAG_LENGTH, 1)
    super
  ensure
    self.class.superclass.send(:remove_const, :AUTH_TAG_LENGTH)
    self.class.superclass.const_set(:AUTH_TAG_LENGTH, auth_tag_length)
  end
end
