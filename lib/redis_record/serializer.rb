require 'redis_record/range_interval'
# typed: strict
#
# This module defines various helper methods on RedisRecord for serialization between the 
# Ruby client and Redis server.
module RedisRecord
  # Raised by Model.where
  class AttributeNotIndexed < StandardError; end
  class WrongAttributeType < TypeError; end
end

module RedisRecord::Serializer
  extend T::Sig

  sig { params(klass: T.any(Module, T.class_of(T::Struct))).void }
  def self.included(klass)
    klass.extend(ClassMethods)
  end
  
  module ClassMethods
    extend T::Sig

    # Redis only allows range queries on floats. To allow range queries on the Ruby Time
    # type, encode_attr_value and decode_attr_value will implicitly encode and decode
    # Time attributes to a float.
    TIME_TYPES = T.let(Set[Time, T.nilable(Time)], T::Set[T.untyped])
    sig { params(attribute: Symbol, val: T.untyped).returns(T.untyped) }
    def encode_attr_value(attribute, val)
      if val && TIME_TYPES.include?(props[attribute][:type])
        val = val.to_f
      end
      val
    end

    sig { params(attribute: Symbol, val: T.untyped).returns(T.untyped) }
    def decode_attr_value(attribute, val)
      if val && TIME_TYPES.include?(props[attribute][:type])
        val = Time.zone.at(val.to_f)
      end
      val
    end

    sig { params(attr_key: Symbol, attr_val: T.untyped).returns(T.untyped)}
    def validate_and_encode_query(attr_key, attr_val)
      # Validate that attributes queried for are index attributes
      if !class_variable_get(:@@index_attributes).include?(attr_key) &&
        !class_variable_get(:@@range_index_attributes).include?(attr_key)
        raise RedisRecord::AttributeNotIndexed.new(
        "#{attr_key} is not an indexed attribute."
        )
      end
      # Validate attribute types for normal index attributes
      attr_type = get_attr_type(attr_key)
      if class_variable_get(:@@index_attributes).include?(attr_key)
        validate_attr_type(attr_val, attr_type)
      else
        # Validate attribute types for range index attributes
        if attr_val.is_a?(RedisRecord::RangeInterval)
          validate_attr_type(attr_val.min, T.cast(T.nilable(attr_type), T::Types::Base))
          validate_attr_type(attr_val.max, T.cast(T.nilable(attr_type), T::Types::Base))
        else
          validate_attr_type(attr_val, attr_type)
        end
        # Range index attributes need to be further encoded into a format understood by the Lua script.
        if attr_val != nil
          attr_val = encode_range_index_attr_val(attr_key, attr_val)
        end
      end
      attr_val
    end

    sig { params(attr_val: T.untyped, attr_type: T.any(Class, T::Types::Base)).void }
    def validate_attr_type(attr_val, attr_type)
      if (attr_type.is_a?(Class) && !attr_val.is_a?(attr_type)) ||
        (attr_type.is_a?(T::Types::Base) && !attr_type.valid?(attr_val))
        raise RedisRecord::WrongAttributeType.new(
          "Expected type #{attr_type}, got #{attr_val.class}"
        )
      end
    end

    sig { params(attribute: Symbol, val: T.untyped).returns([T.untyped, T.untyped]) }
    def encode_range_index_attr_val(attribute, val)
      if val.is_a?(RedisRecord::RangeInterval)
        # nil is treated as -inf and +inf. This is supported in Redis sorted sets
        # so clients aren't required to know the highest and lowest scores in a range
        min_val = !val.min ? '-inf' : encode_attr_value(attribute, val.min)
        max_val = !val.max ? '+inf' : encode_attr_value(attribute, val.max)

        # In Redis, by default min and max is closed. You can prefix the score with '(' to
        # specify an open interval.
        min_val = val.min_exclusive ? '(' + min_val.to_s : min_val.to_s
        max_val = val.max_exclusive ? '(' + max_val.to_s : max_val.to_s
        return [min_val, max_val]
      else
        # Equality queries for range indices are be passed to redis as a range [val, val].
        encoded_val = encode_attr_value(attribute, val)
        [encoded_val, encoded_val]
      end
    end

    sig { params(attr_key: Symbol).returns(T.any(Class, T::Types::Base)) }
    def get_attr_type(attr_key)
      props[attr_key][:type_object]
    end

    sig { params(redis_hash: T::Hash[T.untyped, T.untyped], id: Integer).returns(T.untyped) }
    def coerce_and_set_id(redis_hash, id)
      # Coerce each serialized result returned from Redis back into Model instance
      instance = TypeCoerce.send(:[], self).new.from(from_redis_hash(redis_hash))
      instance.send(:id=, id)
      instance
    end
    sig { returns(String) }
    def model_key
      "RedisRecord:#{name}"
    end

    sig { params(args: T::Hash[T.any(String, Symbol), T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
    def to_redis_hash(args)
      args.map { |key, val| [key.to_sym, encode_attr_value(key.to_sym, val)] }.to_h
    end

    sig { params(args: T::Hash[T.untyped, T.untyped]).returns(T::Hash[T.untyped, T.untyped]) }
    def from_redis_hash(args)
      args.map { |key, val| [key, decode_attr_value(key.to_sym, val)] }.to_h
    end
  end
end
