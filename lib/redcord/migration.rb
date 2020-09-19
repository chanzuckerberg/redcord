# typed: strict
class Redcord::Migration
end

require 'redcord/migration/index'
require 'redcord/migration/ttl'

class Redcord::Migration
  extend T::Sig
  extend T::Helpers
  include Redcord::Migration::Index
  include Redcord::Migration::TTL

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
