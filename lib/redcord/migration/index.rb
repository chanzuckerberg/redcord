# frozen_string_literal: true


module Redcord::Migration::Index
  def remove_index(model, index_name)
    model.redis.scan_each_shard("#{model.model_key}:#{index_name}:*") { |key| _del_set(model, key) }

    attr_set = "#{model.model_key}:#{index_name}"
    nil_attr_set = "#{attr_set}:"

    model.redis.scan_each_shard("#{nil_attr_set}*") { |key| _del_set(model, key) }
    model.redis.scan_each_shard("#{attr_set}*") { |key| _del_zset(model, key) }
  end

  def remove_custom_index(model, index_name)
    index_key = "#{model.model_key}:custom_index:#{index_name}"
    index_content_key = "#{model.model_key}:custom_index:#{index_name}_content"
    model.redis.scan_each_shard("#{index_key}*") { |key| model.redis.unlink(key) }
    model.redis.scan_each_shard("#{index_content_key}*") { |key| model.redis.unlink(key) }
  end

  def _remove_index_from_attr_set(model:, attr_set_name:, index_name:)
    model.redis.srem("#{model.model_key}:#{attr_set_name}", index_name)
  end

  def _del_set(model, key)
    # Use SPOP here to minimize blocking
    loop do
      break unless model.redis.spop(key)
    end

    model.redis.del(key)
  end

  def _del_zset(model, key)
    # ZPOPMIN might not be avaliable on old redis servers
    model.redis.zscan_each(match: key) do |id, _|
      model.redis.zrem(key, id)
    end

    model.redis.del(key)
  end
end
