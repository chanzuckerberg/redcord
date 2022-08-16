module Redcord::Migration::TTL
  def _get_ttl(model)
    model.class_variable_get(:@@ttl) || -1
  end

  def change_ttl_active(model)
    model.redis.scan_each_shard("#{model.model_key}:id:*") do |key|
      model.redis.expire(key, _get_ttl(model))
    end
  end
end
