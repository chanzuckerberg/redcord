# frozen_string_literal: true
require 'yarr'

Time.zone = 'UTC'

RSpec.configure do |config|
  config.before(:each) do
    RedisRecord::Base.redis.flushdb
  end
end
