# frozen_string_literal: true
require 'simplecov'

SimpleCov.start

if ENV['CI'] == 'true'
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

RSpec.configure do |config|
  require 'redcord'

  Time.zone = 'UTC'

  config.before(:each) do
    Redcord::Base.redis.each_shard { |shard| shard.flushdb }
    Redcord::Redis.load_server_scripts!
    Redcord.establish_connections
  end
end
