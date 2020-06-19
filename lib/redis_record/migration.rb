# typed: strict
class RedisRecord::Migration
end

require 'redis_record/migration/ttl'

class RedisRecord::Migration
  extend T::Sig
  extend T::Helpers
  include RedisRecord::Migration::TTL

  abstract!

  sig { returns(Redis) }
  attr_reader :redis

  sig { params(redis: Redis).void }
  def initialize(redis)
    @redis = redis
  end

  sig { abstract.void }
  def up; end

  sig { abstract.void }
  def down; end
end
