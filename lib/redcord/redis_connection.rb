# frozen_string_literal: true

# typed: false

require 'rails'

require 'redcord/lua_script_reader'
require 'redcord/redis'

module Redcord::RedisConnection
  @connections = T.let(nil, T.nilable(T::Hash[String, T.untyped]))
  @procs_to_prepare = T.let([], T::Array[Proc])

  def self.included(klass)
    klass.extend(ClassMethods)
    klass.include(InstanceMethods)
  end

  module ClassMethods
    def connection_config
      env_config = Redcord::Base.configurations[Rails.env]
      (env_config[name.underscore] || env_config['default']).symbolize_keys
    end

    def redis
      Redcord::RedisConnection.connections[name.underscore] ||= prepare_redis!
    end

    def establish_connection
      Redcord::RedisConnection.connections[name.underscore] = prepare_redis!
    end

    def redis=(redis)
      Redcord::RedisConnection.connections[name.underscore] =
        prepare_redis!(redis)
    end

    # We prepare the model definition such as TTL, index, and uniq when we
    # establish a Redis connection (once per connection) instead of sending the
    # definitions in each Redis query.
    #
    # TODO: Replace this with Redcord migrations
    def prepare_redis!(client = nil)
      return client if client.is_a?(Redcord::Redis)

      client = Redcord::Redis.new(
        **(
          if client.nil?
            connection_config
          else
            client.instance_variable_get(:@options)
          end
        ),
        logger: Redcord::Logger.proxy,
      )

      client.ping
      client
    end
  end

  module InstanceMethods
    extend T::Sig

    def redis
      self.class.redis
    end
  end

  def self.merge_and_resolve_default(config)
    env = Rails.env
    config[env] = {} unless config.include?(env)
    config[env]['default'] = {} unless config[env].include?('default')
    config
  end

  def self.connections
    @connections ||= {}
  end

  def self.procs_to_prepare
    @procs_to_prepare
  end
end

module Redcord
  def self.establish_connections
    Redcord::Base.descendants.select(&:name).each(&:establish_connection)
  end
end
