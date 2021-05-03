# frozen_string_literal: true

# typed: strict

require 'rails'

require 'redcord/lua_script_reader'
require 'redcord/redis'
require 'redcord/connection_pool'

module Redcord::RedisConnection
  extend T::Sig
  extend T::Helpers

  RedcordClientType = T.type_alias { T.any(Redcord::Redis, Redcord::ConnectionPool) }

  @connections = T.let(nil, T.nilable(T::Hash[String, T.untyped]))
  @procs_to_prepare = T.let([], T::Array[Proc])

  sig { params(klass: T.any(Module, T.class_of(T::Struct))).void }
  def self.included(klass)
    klass.extend(ClassMethods)
    klass.include(InstanceMethods)
  end

  module ClassMethods
    extend T::Sig

    sig { returns(T::Hash[Symbol, T.untyped]) }
    def connection_config
      env_config = Redcord::Base.configurations[Rails.env]
      (env_config[name.underscore] || env_config['default']).symbolize_keys
    end

    sig { returns(RedcordClientType) }
    def redis
      Redcord::RedisConnection.connections[name.underscore] ||= prepare_redis!
    end

    sig { returns(RedcordClientType) }
    def establish_connection
      Redcord::RedisConnection.connections[name.underscore] = prepare_redis!
    end

    sig { params(redis: Redis).returns(RedcordClientType) }
    def redis=(redis)
      Redcord::RedisConnection.connections[name.underscore] =
        prepare_redis!(redis)
    end

    # We prepare the model definition such as TTL, index, and uniq when we
    # establish a Redis connection (once per connection) instead of sending the
    # definitions in each Redis query.
    #
    # TODO: Replace this with Redcord migrations
    sig { params(client: T.nilable(Redis)).returns(RedcordClientType) }
    def prepare_redis!(client = nil)
      return client if client.is_a?(Redcord::Redis) || client.is_a?(Redcord::ConnectionPool)

      options = client.nil? ? connection_config : client.instance_variable_get(:@options)
      client =
        if options[:pool]
          Redcord::ConnectionPool.new(
            pool_size: options[:pool],
            timeout: options[:connection_timeout] || 1.0,
            **options
          )
        else
          Redcord::Redis.new(**options, logger: Redcord::Logger.proxy)
        end

      client.ping
      client
    end
  end

  module InstanceMethods
    extend T::Sig

    sig { returns(RedcordClientType) }
    def redis
      self.class.redis
    end
  end

  sig {
    params(
      config: T::Hash[String, T.untyped],
    ).returns(T::Hash[String, T.untyped])
  }
  def self.merge_and_resolve_default(config)
    env = Rails.env
    config[env] = {} unless config.include?(env)
    config[env]['default'] = {} unless config[env].include?('default')
    config
  end

  sig { returns(T::Hash[String, T.untyped]) }
  def self.connections
    @connections ||= {}
  end

  sig { returns(T::Array[Proc]) }
  def self.procs_to_prepare
    @procs_to_prepare
  end

  mixes_in_class_methods(ClassMethods)
end

module Redcord
  sig { void }
  def self.establish_connections
    Redcord::Base.descendants.select(&:name).each(&:establish_connection)
  end
end
