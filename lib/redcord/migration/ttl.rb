# typed: false
module Redcord::Migration::TTL
  extend T::Sig

  sig { params(model: T.class_of(Redcord::Base)).returns(T.untyped) }
  def _get_ttl(model)
    model.class_variable_get(:@@ttl) || -1
  end

  sig { params(model: T.class_of(Redcord::Base)).void }
  def change_ttl_active(model)
    model.redis.scan_each_shard("#{model.model_key}:id:*") do |key|
      model.redis.expire(key, _get_ttl(model))
    end
  end
end
