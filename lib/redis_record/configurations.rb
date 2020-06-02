# typed: strict
#
#  This allows us to configure Redis connections for RedisRecord. Redis
#  connections can be set at the base level or model level.
#
#  Connections are established by reading the connection configurations for the
#  current Rails environment (development, test, or production). When a model
#  level connection config is not found, the base level config will be used (which
#  is a common case in the test environment).
#
#  For example, in with yaml file:
#  ```
#  my_env:
#    default:
#      url: redis_url_1
#    my_model:
#      url: redis_url_2
#  ```
#
#  All models other than my model will connect to redis_url_1. My_model connects
#  to redis_url_2.
#
#  It is also possible to change the connection in runtime by setting the new
#  configuration and call `establish_connection`. `establish_connection` clears
#  out the current connection at the mode or base level, and make a new based on
#  the latest connection config, which is similar to ActiveRecord.
#
#  Unlike `ActiveRecord::Base.establish_connection`, it does not take any
#  arguments and only uses the current configuration. We can change the
#  connection config anytime we want, however, the connection won't actually
#  change until we call establish_connection.
#
#  For example,
#  ```
#  RedisRecord::Base.configurations = {env => {'spec_model' => {'url' => fake_url}}}
#  Model_class.redis # the same connection
#
#  model_class.establish_connection
#  Model_class.redis # using the connection to fake_url
#  ```
#
module RedisRecord::Configurations
  sig { params(klass: Module).void }
  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    @@configurations = T.let(
      RedisRecord::RedisConnection.merge_and_resolve_default({}),
      T::Hash[String, T.untyped]
    )

    sig { returns(T::Hash[String, T.untyped]) }
    def configurations
      @@configurations
    end

    sig { params(config: T::Hash[String, T.untyped]).void }
    def configurations=(config)
      @@configurations = RedisRecord::RedisConnection.merge_and_resolve_default(config)
    end
  end

  mixes_in_class_methods(ClassMethods)
end
