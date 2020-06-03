# typed: strict
#
# A Redis ORM API inspired by ActiveRecord:
# - It provides atomic CRUD operations
#   - One round trip per operation
# - Model attributes are type-checked by sorbet
#
require 'redis_record/logger'
require 'redis_record/configurations'
require 'redis_record/redis_connection'
require 'redis_record/actions'
require 'redis_record/attribute'
require 'redis_record/ttl'

module RedisRecord::Base
  extend T::Sig
  extend T::Helpers

  # Base level methods
  #   Redis logger can be configured at the baes level. Redis connections can
  #   be configured at the base-level, the model level, and Rails environment
  #   level.
  include RedisRecord::Configurations
  include RedisRecord::Logger
  include RedisRecord::RedisConnection

  abstract!

  sig { params(klass: T.class_of(T::Struct)).void }
  def self.included(klass)
    # RedisRecord uses `T::Struct` to validate the attribute types. The
    # RedisRecord models need to inherit `T::Struct` and include
    # `RedisRecord::Base`, for example:
    #
    #   class MyRedisModel < T::Struct
    #     include RedisRecord::Base
    #
    #     attribute :my_redis_value, Integer
    #   end
    #
    # See more examples in spec/lib/redis_record_spec.rb.

    klass.class_eval do
      # RedisRecord Model level methods
      include RedisRecord::Actions
      include RedisRecord::Attribute
      include RedisRecord::RedisConnection
      include RedisRecord::TTL

      # RedisRecord stores the serialized model as a hash on Redis. When
      # reading a model from Redis, the hash fields are deserialized and
      # coerced to the specified attribute types. Like ActiveRecord,
      # RedisRecord manages the created_at and updated_at fields behind the
      # scene.
      prop :created_at, T.nilable(Time)
      prop :updated_at, T.nilable(Time)
    end
  end
end
