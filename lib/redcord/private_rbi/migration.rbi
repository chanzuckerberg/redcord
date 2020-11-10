# typed: strict
class Redcord::Migration
  include Redcord::Migration::Index
  include Redcord::Migration::TTL

  abstract!

  sig { returns(Redis) }
  attr_reader :redis

  sig { params(redis: Redis).void }
  def initialize(redis)
  end

  sig { abstract.void }
  def up; end

  sig { abstract.void }
  def down; end
end
