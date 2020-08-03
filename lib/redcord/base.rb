# frozen_string_literal: true
#
# typed: strict
#
# A Redis ORM API inspired by ActiveRecord:
# - It provides atomic CRUD operations
#   - One round trip per operation
# - Model attributes are type-checked by sorbet
#
require 'redcord/actions'
require 'redcord/attribute'
require 'redcord/configurations'
require 'redcord/logger'
require 'redcord/redis_connection'
require 'redcord/serializer'

module Redcord::Base
  extend T::Sig
  extend T::Helpers

  # Base level methods
  #   Redis logger can be configured at the baes level. Redis connections can
  #   be configured at the base-level, the model level, and Rails environment
  #   level.
  include Redcord::Configurations
  include Redcord::Logger
  include Redcord::RedisConnection

  abstract!

  sig { params(klass: T.class_of(T::Struct)).void }
  def self.included(klass)
    # Redcord uses `T::Struct` to validate the attribute types. The
    # Redcord models need to inherit `T::Struct` and include
    # `Redcord::Base`, for example:
    #
    #   class MyRedisModel < T::Struct
    #     include Redcord::Base
    #
    #     attribute :my_redis_value, Integer
    #   end
    #
    # See more examples in spec/lib/redcord_spec.rb.

    klass.class_eval do
      # Redcord Model level methods
      include Redcord::Serializer
      include Redcord::Actions
      include Redcord::Attribute
      include Redcord::RedisConnection

      # Redcord stores the serialized model as a hash on Redis. When
      # reading a model from Redis, the hash fields are deserialized and
      # coerced to the specified attribute types. Like ActiveRecord,
      # Redcord manages the created_at and updated_at fields behind the
      # scene.
      attribute :id, T.nilable(Integer), index: true
      attribute :created_at, T.nilable(Time), index: true
      attribute :updated_at, T.nilable(Time), index: true
    end
  end
end
