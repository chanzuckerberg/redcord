# frozen_string_literal: true

# typed: strict

require 'rails'

require 'redcord/lua_script_reader'
require 'redcord/prepared_redis'

module Redcord::RedisConnection
  extend T::Sig
  extend T::Helpers

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

    sig { returns(Redcord::PreparedRedis) }
    def redis
      Redcord::RedisConnection.connections[name.underscore] ||= prepare_redis!
    end

    sig { returns(Redcord::PreparedRedis) }
    def establish_connection
      Redcord::RedisConnection.connections[name.underscore] = prepare_redis!
    end

    sig { params(redis: Redis).returns(Redcord::PreparedRedis) }
    def redis=(redis)
      Redcord::RedisConnection.connections[name.underscore] =
        prepare_redis!(redis)
    end

    # We prepare the model definition such as TTL, index, and uniq when we
    # establish a Redis connection (once per connection) instead of sending the
    # definitions in each Redis query.
    #
    # TODO: Replace this with Redcord migrations
    sig { params(client: T.nilable(Redis)).returns(Redcord::PreparedRedis) }
    def prepare_redis!(client = nil)
      return client if client.is_a?(Redcord::PreparedRedis)

      client = Redcord::PreparedRedis.new(
        **(
          if client.nil?
            connection_config
          else
            client.instance_variable_get(:@options)
          end
        ),
        logger: Redcord::Logger.proxy,
      )

      client.pipelined do
        Redcord::RedisConnection.procs_to_prepare.each do |proc_to_prepare|
          proc_to_prepare.call(client)
        end
      end

      client
    end
  end

  module InstanceMethods
    extend T::Sig

    sig { returns(Redcord::PreparedRedis) }
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
