# frozen_string_literal: true
require 'simplecov'

SimpleCov.start

if ENV['CI'] == 'true'
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

RSpec.configure do |config|
  require 'redis_record'

  Time.zone = 'UTC'

  config.before(:each) do
    RedisRecord::Base.redis.flushdb
  end
end
