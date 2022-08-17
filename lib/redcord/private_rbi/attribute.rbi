# typed: true
module Redcord::Attribute
  extend T::Sig
  extend T::Helpers

  sig { params(klass: T.class_of(T::Struct)).void }
  def self.included(klass)
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
    end

    sig { params(index_name: Symbol, attrs: T::Array[Symbol]).void }
    def custom_index(index_name, attrs)
    end

    sig { params(duration: T.nilable(ActiveSupport::Duration)).void }
    def ttl(duration)
    end

    def shard_by_attribute(attr=nil)
    end

    sig { returns(Integer) }
    def _script_arg_ttl
    end

    sig { returns(T::Array[Symbol]) }
    def _script_arg_index_attrs
    end

    sig { returns(T::Array[Symbol]) }
    def _script_arg_range_index_attrs
    end

    sig { returns(T::Hash[Symbol, T::Array]) }
    def _script_arg_custom_index_attrs
    end

    private

    sig { params(type: T.any(Class, T::Types::Base)).returns(T::Boolean) }
    def should_range_index?(type)
    end

    sig { params(type: T.any(Class, T::Types::Base)).returns(T::Boolean) }
    def can_custom_index?(type)
    end
  end

  module InstanceMethods
    extend T::Sig

    sig { returns(T.nilable(String)) }
    def hash_tag
    end
  end
end

module Redcord::Base
  extend Redcord::Attribute::ClassMethods

  include Redcord::Attribute::InstanceMethods
end
