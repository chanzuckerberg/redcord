# typed: true
module Redcord::Serializer
  extend T::Sig

  sig { params(klass: T.any(Module, T.class_of(T::Struct))).void }
  def self.included(klass)
  end

  module ClassMethods
    TIME_TYPES = T.let(Set[Time, T.nilable(Time)], T::Set[T.untyped])

    sig { params(attribute: Symbol, val: T.untyped).returns(T.untyped) }
    def encode_attr_value(attribute, val)
    end

    sig { params(attribute: Symbol, val: T.untyped).returns(T.untyped) }
    def decode_attr_value(attribute, val)
    end

    sig { params(attr_key: Symbol, attr_val: T.untyped).returns(T.untyped)}
    def validate_types_and_encode_query(attr_key, attr_val)
    end

    # Validate that attributes queried for are index attributes
    # For custom index: validate that attributes are present in specified index
    sig { params(attr_keys: T::Array[Symbol], custom_index_name: T.nilable(Symbol)).void}
    def validate_index_attributes(attr_keys, custom_index_name: nil)
    end

    # Validate exclusive ranges not used; Change all query conditions to range form;
    # The position of the attribute and type of query is validated on Lua side
    sig { params(query_conditions: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped])}
    def validate_and_adjust_custom_index_query_conditions(query_conditions)
    end

    sig {
      params(
        attr_val: T.untyped,
        attr_type: T.any(Class, T::Types::Base),
      ).void
    }
    def validate_range_attr_types(attr_val, attr_type)
    end

    sig {
      params(
        attr_val: T.untyped,
        attr_type: T.any(Class, T::Types::Base),
      ).void
    }
    def validate_attr_type(attr_val, attr_type)
    end

    sig {
      params(
        attribute: Symbol,
        val: T.untyped,
      ).returns([T.untyped, T.untyped])
    }
    def encode_range_index_attr_val(attribute, val)
    end

    sig { params(attr_key: Symbol).returns(T.any(Class, T::Types::Base)) }
    def get_attr_type(attr_key)
    end

    sig {
      params(
        redis_hash: T::Hash[T.untyped, T.untyped],
        id: String,
      ).returns(T.untyped)
    }
    def coerce_and_set_id(redis_hash, id)
    end

    sig { returns(String) }
    def model_key
    end

    sig {
      params(
        args: T::Hash[T.any(String, Symbol), T.untyped],
      ).returns(T::Hash[Symbol, T.untyped])
    }
    def to_redis_hash(args)
    end

    sig {
      params(
        args: T::Hash[T.untyped, T.untyped],
      ).returns(T::Hash[T.untyped, T.untyped])
    }
    def from_redis_hash(args)
    end
  end
end
