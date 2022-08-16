require 'redcord/attribute'

class Redcord::RangeInterval < T::Struct
  prop :min, T.nilable(Redcord::Attribute::RangeIndexType), default: nil
  prop :min_exclusive, T::Boolean, default: false
  prop :max, T.nilable(Redcord::Attribute::RangeIndexType), default: nil
  prop :max_exclusive, T::Boolean, default: false
end
