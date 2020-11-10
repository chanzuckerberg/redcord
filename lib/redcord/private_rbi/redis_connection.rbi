# typed: true

module Redcord::RedisConnection
  extend T::Sig
  extend T::Helpers

  @connections = T.let(nil, T.nilable(T::Hash[String, T.untyped]))
  @procs_to_prepare = T.let([], T::Array[Proc])

  sig { params(klass: T.any(Module, T.class_of(T::Struct))).void }
  def self.included(klass)
  end

  module ClassMethods
    extend T::Sig

    sig { returns(T::Hash[Symbol, T.untyped]) }
    def connection_config
    end

    sig { returns(Redcord::Redis) }
    def redis
    end

    sig { returns(Redcord::Redis) }
    def establish_connection
    end

    sig { params(redis: Redis).returns(Redcord::Redis) }
    def redis=(redis)
    end

    # We prepare the model definition such as TTL, index, and uniq when we
    # establish a Redis connection (once per connection) instead of sending the
    # definitions in each Redis query.
    #
    # TODO: Replace this with Redcord migrations
    sig { params(client: T.nilable(Redis)).returns(Redcord::Redis) }
    def prepare_redis!(client = nil)
    end
  end

  module InstanceMethods
    extend T::Sig

    sig { returns(Redcord::Redis) }
    def redis
    end
  end

  sig {
    params(
      config: T::Hash[String, T.untyped],
    ).returns(T::Hash[String, T.untyped])
  }
  def self.merge_and_resolve_default(config)
  end

  sig { returns(T::Hash[String, T.untyped]) }
  def self.connections
  end

  sig { returns(T::Array[Proc]) }
  def self.procs_to_prepare
  end
end

module Redcord::Base
  extend Redcord::RedisConnection::ClassMethods

  include Redcord::RedisConnection::InstanceMethods
end

module Redcord
  sig { void }
  def self.establish_connections
  end
end
