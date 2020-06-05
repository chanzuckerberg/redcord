# typed: strict
require 'yarr/prepared_redis'
require 'yarr/lua_script_reader'

module RedisRecord::RedisConnection
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
      env_config = RedisRecord::Base.configurations[Rails.env]
      (env_config[name.underscore] || env_config['default']).symbolize_keys
    end

    sig { returns(RedisRecord::PreparedRedis) }
    def redis
      RedisRecord::RedisConnection.connections[name.underscore] ||= prepare_redis!
    end

    sig { returns(RedisRecord::PreparedRedis) }
    def establish_connection
      RedisRecord::RedisConnection.connections[name.underscore] = prepare_redis!
    end

    sig { params(redis: Redis).returns(RedisRecord::PreparedRedis) }
    def redis=(redis)
      RedisRecord::RedisConnection.connections[name.underscore] = prepare_redis!(redis)
    end

    # We prepare the model definition such as TTL, index, and uniq when we
    # establish a Redis connection (once per connection) instead of sending the
    # definitions in each Redis query.
    #
    # TODO: Replace this with RedisRecord migrations
    sig { params(client: T.nilable(Redis)).returns(RedisRecord::PreparedRedis) }
    def prepare_redis!(client=nil)
      return client if client.is_a?(RedisRecord::PreparedRedis)

      client = RedisRecord::PreparedRedis.new(
        **(client.nil? ? connection_config : client.instance_variable_get(:@options)),
        logger: RedisRecord::Logger.proxy,
      )

      client.pipelined do
        RedisRecord::RedisConnection.procs_to_prepare.each do |proc_to_prepare|
          proc_to_prepare.call(client)
        end
      end

      script_names = RedisRecord::ServerScripts.instance_methods
      res = client.pipelined do
        script_names.each do |script_name|
          client.script(:load, RedisRecord::LuaScriptReader.read_lua_script(script_name.to_s))
        end
      end

      client.redis_record_server_script_shas = script_names.zip(res).to_h
      client
    end
  end

  module InstanceMethods
    extend T::Sig

    sig { returns(RedisRecord::PreparedRedis) }
    def redis
      self.class.redis
    end
  end

  sig { params(config: T::Hash[String, T.untyped]).returns(T::Hash[String, T.untyped]) }
  def self.merge_and_resolve_default(config)
    env = Rails.env
    config[env] = {} if !config.include?(env)
    config[env]['default'] = {} if !config[env].include?('default')
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
