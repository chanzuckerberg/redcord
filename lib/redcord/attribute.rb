# frozen_string_literal: true

# typed: ignore
module Redcord
  class InvalidAttribute < StandardError; end
end

module Redcord::Attribute
  # We implicitly determine what should be a range index on Redis based on Ruby
  # type.
  RangeIndexType = T.type_alias {
    T.any(
      Float,
      Integer,
      NilClass,
      Numeric,
      Time,
    )
  }

  # Implicitly determine what data type can be a used in custom index on Redis based on Ruby type.
  # Custom index currently supports positive integers with up to 19 characters in decimal notation, 
  # will raise error in Lua if bigger numbers are used.
  CustomIndexType = T.type_alias {
    T.any(
      Integer,
      Time,
    )
  }

  def self.included(klass)
    klass.extend(ClassMethods)
    klass.include(InstanceMethods)
    klass.class_variable_set(:@@index_attributes, Set.new)
    klass.class_variable_set(:@@range_index_attributes, Set.new)
    klass.class_variable_set(:@@custom_index_attributes, Hash.new { |h, k| h[k] = [] })
    klass.class_variable_set(:@@ttl, nil)
    klass.class_variable_set(:@@shard_by_attribute, nil)
  end

  module ClassMethods
    def attribute(name, type, options = {})
      # TODO: support uniq options
      # TODO: validate types
      prop(name, type)

      index_attribute(name, type) if options[:index]
    end

    def index_attribute(attr, type)
      if should_range_index?(type)
        class_variable_get(:@@range_index_attributes) << attr
      else
        class_variable_get(:@@index_attributes) << attr
      end
    end

    def custom_index(index_name, attrs)
      attrs.each do |attr|
        type = props[attr][:type]
        if !can_custom_index?(type)
          raise(Redcord::WrongAttributeType, "Custom index doesn't support '#{type}' attributes.")
        end
      end
      shard_by_attr = class_variable_get(:@@shard_by_attribute)
      if shard_by_attr and shard_by_attr != attrs.first
        raise(
          Redcord::CustomIndexInvalidDesign,
          "shard_by attribute '#{shard_by_attr}' must be placed first in '#{index_name}' index"
        )
      end
      class_variable_get(:@@custom_index_attributes)[index_name] = attrs
    end

    def ttl(duration)
      class_variable_set(:@@ttl, duration)
    end

    def shard_by_attribute(attr=nil)
      return class_variable_get(:@@shard_by_attribute) if attr.nil?

      # attr must be an non-index attribute (index: false)
      if class_variable_get(:@@index_attributes).include?(attr) ||
          class_variable_get(:@@range_index_attributes).include?(attr)
        raise Redcord::InvalidAttribute, "Cannot shard by an index attribute '#{attr}'"
      end

      class_variable_get(:@@custom_index_attributes).each do |index_name, attrs|
        if attr != attrs.first
          raise(
            Redcord::CustomIndexInvalidDesign,
            "shard_by attribute '#{attr}' must be placed first in '#{index_name}' index"
          )
        end

        # Delete the shard_by_attribute since it would be a constant in the
        # custom index set
        attrs.shift
      end

      class_variable_set(:@@shard_by_attribute, attr)
    end

    def _script_arg_ttl
      class_variable_get(:@@ttl)&.to_i || -1
    end

    def _script_arg_index_attrs
      class_variable_get(:@@index_attributes).to_a
    end

    def _script_arg_range_index_attrs
      class_variable_get(:@@range_index_attributes).to_a
    end

    def _script_arg_custom_index_attrs
      class_variable_get(:@@custom_index_attributes)
    end

    private

    def should_range_index?(type)
      # Change Ruby raw type to Sorbet type in order to call subtype_of?
      type = T::Types::Simple.new(type) if type.is_a?(Class)

      type.subtype_of?(RangeIndexType)
    end

    def can_custom_index?(type)
      # Change Ruby raw type to Sorbet type in order to call subtype_of?
      type = T::Types::Simple.new(type) if type.is_a?(Class)
      type.subtype_of?(CustomIndexType)
    end
  end

  module InstanceMethods
    def hash_tag
      attr = self.class.class_variable_get(:@@shard_by_attribute)

      return nil if attr.nil?

      # A blank hash tag would cause MOVED error in cluster mode
      tag = send(attr)
      default_tag = '__redcord_hash_tag_null__'

      if tag == default_tag
        raise Redcord::InvalidAttribute, "#{attr}=#{default_tag} conflicts with default hash_tag value"
      end

      "{#{tag || default_tag}}"
    end
  end
end
