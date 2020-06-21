# typed: strict
module Redcord::Migration::TTL
  extend T::Sig

  # This won't change ttl until we call update on a record
  sig { params(model: T.class_of(Redcord::Base)).void }
  def change_ttl_passive(model)
    ttl = model.class_variable_get(:@@ttl)
    model.redis.set("#{model.model_key}:ttl", ttl ? ttl : -1)
  end
end
