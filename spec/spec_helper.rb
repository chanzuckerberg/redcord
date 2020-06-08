# frozen_string_literal: true
require 'yarr'

RSpec.configure do |config|
  config.before(:each) do
    RedisRecord::Base.redis.flushdb
  end
end
