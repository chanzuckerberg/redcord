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
    klass.class_variable_set(:@@index_attributes, Set.new)
    klass.class_variable_set(:@@range_index_attributes, Set.new)
    klass.class_variable_set(:@@custom_indexes, Array.new)
    klass.class_variable_set(:@@ttl, nil)
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
        sadd_proc_on_redis_connection('range_index_attrs', attr.to_s)
      else
        class_variable_get(:@@index_attributes) << attr
        sadd_proc_on_redis_connection('index_attrs', attr.to_s)
      end
    end

    sig { params(name: String, attrs: T::Array[Symbol]).void }
    def custom_index(name, attrs)
      class_variable_get(:@@custom_indexes) << attrs
      zadd_proc_on_redis_connection("custom_indexes_#{name}", attrs.map(&:to_s))
    end

    sig { params(duration: T.nilable(ActiveSupport::Duration)).void }
    def ttl(duration)
      class_variable_set(:@@ttl, duration)
    end

    private

    sig { params(redis_key: String, item_to_add: String).void }
    def sadd_proc_on_redis_connection(redis_key, item_to_add)
      # TODO: Currently we're setting indexed attributes through procs that are
      # run when a RedisConnection is established. This should be replaced with
      # migrations
      Redcord::RedisConnection.procs_to_prepare << proc do |redis|
        redis.sadd("#{model_key}:#{redis_key}", item_to_add)
      end
    end

    sig { params(redis_key: String, items_to_add: T::Array[String]).void }
    def zadd_proc_on_redis_connection(redis_key, items_to_add)
      order = 1
      Redcord::RedisConnection.procs_to_prepare << proc do |redis|
        items_to_add.each do |item_to_add|
          redis.zadd("#{model_key}:#{redis_key}", order, item_to_add)
          order += 1
        end
      end
    end

    sig { params(type: T.any(Class, T::Types::Base)).returns(T::Boolean) }
    def should_range_index?(type)
      # Change Ruby raw type to Sorbet type in order to call subtype_of?
      type = T::Types::Simple.new(type) if type.is_a?(Class)

      type.subtype_of?(RangeIndexType)
    end
  end

  mixes_in_class_methods(ClassMethods)
end
