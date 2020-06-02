# typed: strict
class RedisRecord::RangeInterval < T::Struct
  prop :min, T.nilable(RedisRecord::Attribute::RangeIndexType), default: nil
  prop :min_exclusive, T::Boolean, default: false
  prop :max, T.nilable(RedisRecord::Attribute::RangeIndexType), default: nil
  prop :max_exclusive, T::Boolean, default: false
end
