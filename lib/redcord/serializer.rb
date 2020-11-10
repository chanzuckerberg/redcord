# frozen_string_literal: true

# typed: false

require 'redcord/range_interval'

module Redcord
  # Raised by Model.where
  class AttributeNotIndexed < StandardError; end
  class WrongAttributeType < TypeError; end
  class CustomIndexInvalidQuery < StandardError; end
  class CustomIndexInvalidDesign < StandardError; end
end

# This module defines various helper methods on Redcord for serialization
# between the  Ruby client and Redis server.
module Redcord::Serializer
  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    # Redis only allows range queries on floats. To allow range queries on the
    # Ruby Time type, encode_attr_value and decode_attr_value will implicitly
    # encode and decode Time attributes to a float.
    TIME_TYPES = T.let(Set[Time, T.nilable(Time)], T::Set[T.untyped])

    def encode_attr_value(attribute, val)
      if !val.blank? && TIME_TYPES.include?(props[attribute][:type])
        time_in_nano_sec = val.to_i * 1_000_000_000
        time_in_nano_sec >= 0 ? time_in_nano_sec + val.nsec : time_in_nano_sec - val.nsec
      elsif val.is_a?(Float)
        # Encode as round-trippable float64
        '%1.16e' % [val]
      else
        val
      end
    end

    def decode_attr_value(attribute, val)
      if !val.blank? && TIME_TYPES.include?(props[attribute][:type])
        val = val.to_i
        nsec = val >= 0 ? val % 1_000_000_000 : -val % 1_000_000_000

        Time.zone.at(val / 1_000_000_000).change(nsec: nsec)
      else
        val
      end
    end

    def validate_types_and_encode_query(attr_key, attr_val)
      # Validate attribute types for index attributes
      attr_type = get_attr_type(attr_key)
      if class_variable_get(:@@index_attributes).include?(attr_key) || attr_key == shard_by_attribute
        validate_attr_type(attr_val, attr_type)
      else
        validate_range_attr_types(attr_val, attr_type)

        # Range index attributes need to be further encoded into a format
        # understood by the Lua script.
        unless attr_val.nil?
          attr_val = encode_range_index_attr_val(attr_key, attr_val)
        end
      end
      attr_val
    end

    # Validate that attributes queried for are index attributes
    # For custom index: validate that attributes are present in specified index
    def validate_index_attributes(attr_keys, custom_index_name: nil)
      custom_index_attributes = class_variable_get(:@@custom_index_attributes)[custom_index_name]
      attr_keys.each do |attr_key|
        next if attr_key == shard_by_attribute

        if !custom_index_attributes.empty?
          if !custom_index_attributes.include?(attr_key)
            raise(
              Redcord::AttributeNotIndexed,
              "#{attr_key} is not a part of #{custom_index_name} index.",
            )
          end
        else
          if !class_variable_get(:@@index_attributes).include?(attr_key) &&
            !class_variable_get(:@@range_index_attributes).include?(attr_key)
            raise(
              Redcord::AttributeNotIndexed,
              "#{attr_key} is not an indexed attribute.",
            )
          end
        end
      end
    end

    # Validate exclusive ranges not used; Change all query conditions to range form;
    # The position of the attribute and type of query is validated on Lua side
    def validate_and_adjust_custom_index_query_conditions(query_conditions)
      adjusted_query_conditions = query_conditions.clone
      query_conditions.each do |attr_key, condition|
        if !condition.is_a?(Array)
          adjusted_query_conditions[attr_key] = [condition, condition]
        elsif condition[0].to_s[0] == '(' or condition[1].to_s[0] == '('
          raise(Redcord::CustomIndexInvalidQuery, "Custom index doesn't support exclusive ranges")
        end
      end
      adjusted_query_conditions
    end

    def validate_range_attr_types(attr_val, attr_type)
      # Validate attribute types for range index attributes
      if attr_val.is_a?(Redcord::RangeInterval)
        validate_attr_type(
          attr_val.min,
          T.cast(T.nilable(attr_type), T::Types::Base),
        )
        validate_attr_type(
          attr_val.max,
          T.cast(T.nilable(attr_type), T::Types::Base),
        )
      else
        validate_attr_type(attr_val, attr_type)
      end
    end

    def validate_attr_type(attr_val, attr_type)
      if (attr_type.is_a?(Class) && !attr_val.is_a?(attr_type)) ||
         (attr_type.is_a?(T::Types::Base) && !attr_type.valid?(attr_val))
        raise(
          Redcord::WrongAttributeType,
          "Expected type #{attr_type}, got #{attr_val.class.name}",
        )
      end
    end

    def encode_range_index_attr_val(attribute, val)
      if val.is_a?(Redcord::RangeInterval)
        # nil is treated as -inf and +inf. This is supported in Redis sorted
        # sets so clients aren't required to know the highest and lowest scores
        # in a range
        min_val = !val.min ? '-inf' : encode_attr_value(attribute, val.min)
        max_val = !val.max ? '+inf' : encode_attr_value(attribute, val.max)

        # In Redis, by default min and max is closed. You can prefix the score
        # with '(' to specify an open interval.
        min_val = val.min_exclusive ? '(' + min_val.to_s : min_val.to_s
        max_val = val.max_exclusive ? '(' + max_val.to_s : max_val.to_s
        [min_val, max_val]
      else
        # Equality queries for range indices are be passed to redis as a range
        # [val, val].
        encoded_val = encode_attr_value(attribute, val)
        [encoded_val, encoded_val]
      end
    end

    def get_attr_type(attr_key)
      props[attr_key][:type_object]
    end

    def coerce_and_set_id(redis_hash, id)
      # Coerce each serialized result returned from Redis back into Model
      # instance
      instance = TypeCoerce.send(:[], self).new.from(from_redis_hash(redis_hash))
      instance.send(:id=, id)
      instance
    end

    def model_key
      "Redcord:#{name}"
    end

    def to_redis_hash(args)
      args.map do |key, val|
        [key.to_sym, encode_attr_value(key.to_sym, val)]
      end.to_h
    end

    def from_redis_hash(args)
      args.map { |key, val| [key, decode_attr_value(key.to_sym, val)] }.to_h
    end
  end
end
