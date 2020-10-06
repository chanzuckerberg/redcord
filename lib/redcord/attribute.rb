# frozen_string_literal: true

# typed: strict

module Redcord::Attribute
  extend T::Sig
  extend T::Helpers

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

  sig { params(klass: T.class_of(T::Struct)).void }
  def self.included(klass)
    klass.extend(ClassMethods)
    klass.include(InstanceMethods)
    klass.class_variable_set(:@@index_attributes, Set.new)
    klass.class_variable_set(:@@range_index_attributes, Set.new)
    klass.class_variable_set(:@@custom_index_attributes, Hash.new)
    klass.class_variable_set(:@@ttl, nil)
    klass.class_variable_set(:@@shard_by_attribute, nil)
  end

  module ClassMethods
    extend T::Sig

    sig do
      params(
        name: Symbol,
        type: T.untyped, # until smth better is proposed
        options: T::Hash[Symbol, T.untyped],
      ).void
    end
    def attribute(name, type, options = {})
      # TODO: support uniq options
      # TODO: validate types
      prop(name, type)

      index_attribute(name, type) if options[:index]
    end

    sig { params(attr: Symbol, type: T.any(Class, T::Types::Base)).void }
    def index_attribute(attr, type)
      if should_range_index?(type)
        class_variable_get(:@@range_index_attributes) << attr
      else
        class_variable_get(:@@index_attributes) << attr
      end
    end
    
    sig { params(index_name: Symbol, attrs: T::Array[Symbol]).void }
    def custom_index(index_name, attrs)
      class_variable_get(:@@custom_index_attributes)[index_name] = attrs
    end

    sig { params(duration: T.nilable(ActiveSupport::Duration)).void }
    def ttl(duration)
      class_variable_set(:@@ttl, duration)
    end

    def shard_by_attribute(attr)
      # attr must be an index attribute (index: true)
      if !class_variable_get(:@@index_attributes).include?(attr) &&
          !class_variable_get(:@@range_index_attributes).include?(attr)
        raise "Cannot shard by a non-index attribute '#{attr}'"
      end

      # shard_by_attribute is treated as a regular index attribute
      class_variable_get(:@@index_attributes).add(attr)
      class_variable_get(:@@range_index_attributes).delete(attr)

      class_variable_set(:@@shard_by_attribute, attr)
    end

    sig { returns(Integer) }
    def _script_arg_ttl
      class_variable_get(:@@ttl)&.to_i || -1
    end

    sig { returns(T::Array[Symbol]) }
    def _script_arg_index_attrs
      class_variable_get(:@@index_attributes).to_a
    end

    sig { returns(T::Array[Symbol]) }
    def _script_arg_range_index_attrs
      class_variable_get(:@@range_index_attributes).to_a
    end

    sig { returns(T::Hash[Symbol, T::Array]) }
    def _script_arg_custom_index_attrs
      class_variable_get(:@@custom_index_attributes)
    end

    private

    sig { params(type: T.any(Class, T::Types::Base)).returns(T::Boolean) }
    def should_range_index?(type)
      # Change Ruby raw type to Sorbet type in order to call subtype_of?
      type = T::Types::Simple.new(type) if type.is_a?(Class)

      type.subtype_of?(RangeIndexType)
    end
  end

  module InstanceMethods
    extend T::Sig

    sig { returns(T.nilable(String)) }
    def hash_tag
      attr = self.class.class_variable_get(:@@shard_by_attribute)

      return nil if attr.nil?

      # A blank hash tag would cause MOVED error in cluster mode
      tag = send(attr)
      default_tag = '__redcord_hash_tag_null__'

      if tag == default_tag
        raise "#{attr}=#{default_tag} conflicts with default hash_tag value"
      end

      "{#{tag || default_tag}}"
    end
  end

  mixes_in_class_methods(ClassMethods)
end
