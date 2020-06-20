# frozen_string_literal: true
require 'redis_record'
require 'simplecov'

SimpleCov.start

if ENV['CI'] == 'true'
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

Time.zone = 'UTC'

RSpec.configure do |config|
  config.before(:each) do
    RedisRecord::Base.redis.flushdb
  end
end
