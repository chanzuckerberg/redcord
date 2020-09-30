# frozen_string_literal: true

# typed: strict

module Redcord::Attribute
  extend T::Sig
  extend T::Helpers

  # We implicitly determine what should be a range index on Redis based on Ruby
  # type.
  RangeIndexType = T.type_alias {
    T.any(
      T.nilable(Float),
      T.nilable(Integer),
      T.nilable(Time),
    )
  }

  sig { params(klass: T.class_of(T::Struct)).void }
  def self.included(klass)
    klass.extend(ClassMethods)
    klass.include(InstanceMethods)
    klass.class_variable_set(:@@index_attributes, Set.new)
    klass.class_variable_set(:@@range_index_attributes, Set.new)
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

    sig { params(duration: T.nilable(ActiveSupport::Duration)).void }
    def ttl(duration)
      class_variable_set(:@@ttl, duration)
    end

    def shard_by_attribute(attr)
      # attr must be an index attribute (index: true)
      class_variable_set(:@@shard_by_attribute, attr)
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

      "{#{send(attr)}}"
    end
  end

  mixes_in_class_methods(ClassMethods)
end
