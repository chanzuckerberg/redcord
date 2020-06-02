# typed: strict
module RedisRecord::Attribute

  # We implicitly determine what should be a range index on Redis based on Ruby type.
  RangeIndexType = T.type_alias {
    T.any(T.nilable(Time), T.nilable(Float), T.nilable(Integer))
  }

  sig { params(klass: T.class_of(T::Struct)).void }
  def self.included(klass)
    klass.extend(ClassMethods)
    klass.class_variable_set(:@@index_attributes, Set.new)
    klass.class_variable_set(:@@range_index_attributes, Set.new)
  end

  module ClassMethods
    sig do
      params(
        name: Symbol,
        type: T.untyped, # until smth better is proposed
        options: T::Hash[Symbol, T.untyped],
      ).void
    end
    def attribute(name, type, options={})
      # TODO: support uniq options
      prop(name, type)
      if options[:index]
        index_attribute(name, type)
      end
    end
    

    sig { params(attr: Symbol, type: T.any(Class,T::Types::Base)).void }
    def index_attribute(attr, type)
      if should_range_index?(type)
        class_variable_get(:@@range_index_attributes) << attr
        sadd_proc_on_redis_connection("range_index_attrs", attr.to_s)
      else
        class_variable_get(:@@index_attributes) << attr
        sadd_proc_on_redis_connection("index_attrs", attr.to_s)
      end
    end

    private
    sig { params(redis_key: String, item_to_add: String).void }
    def sadd_proc_on_redis_connection(redis_key, item_to_add)
      # TODO: Currently we're setting indexed attributes through procs that are run
      # when a RedisConnection is established. This should be replaced with migrations
      RedisRecord::RedisConnection.procs_to_prepare << Proc.new do |redis|
        redis.sadd("#{model_key}:#{redis_key}", item_to_add)
      end
    end

    sig { params(type: T.any(Class,T::Types::Base)).returns(T::Boolean) }
    def should_range_index?(type)
      # Change Ruby raw type to Sorbet type in order to call subtype_of?
      if type.is_a?(Class)
        type = T::Types::Simple.new(type)
      end
      return type.subtype_of?(RangeIndexType)
    end
  end

  mixes_in_class_methods(ClassMethods)
end
