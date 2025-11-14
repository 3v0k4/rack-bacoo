# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "rack-bacoo"

require "minitest/autorun"

def with(klass, method, stub)
  original = Time.method method
  klass.singleton_class.class_eval { remove_method method }
  klass.define_singleton_method(method, -> { stub })
  yield stub
ensure
  klass.singleton_class.class_eval { remove_method method }
  klass.define_singleton_method(method, original)
end
