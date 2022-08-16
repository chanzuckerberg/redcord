class Redcord::Migration
end

require 'redcord/migration/index'
require 'redcord/migration/ttl'

class Redcord::Migration
  include Redcord::Migration::Index
  include Redcord::Migration::TTL

  attr_reader :redis

  def initialize(redis)
    @redis = redis
  end
end
