# frozen_string_literal: true

# typed: strict

module Redcord::Migration::Index
  extend T::Sig

  sig { params(model: T.class_of(Redcord::Base), index_name: Symbol).void }
  def add_index(model, index_name)
    model.redis.each_shard do |shard|
      if model.class_variable_get(:@@range_index_attributes).include?(index_name)
        shard.sadd("#{model.model_key}:range_index_attrs", index_name.to_s)
      elsif model.class_variable_get(:@@index_attributes).include?(index_name)
        shard.sadd("#{model.model_key}:index_attrs", index_name.to_s)
      else
        raise(
          Redcord::AttributeNotIndexed,
          "#{index_name} is not an indexed attribute.",
        )
      end

      # Loop through existing records and build the index
      shard.scan_each(match: "#{model.model_key}:id:*") do |key|
        index_val = shard.hmget(key, index_name.to_s).first
        id = key.split(':').last

        # Force refresh on the updated index attribute. Use multi to ensure
        # consistency incase this migration failed in the middle
        shard.multi
        shard.update_hash(
          model.model_key,
          id,
          {index_name => index_val.empty? ? 'redcord_temp_val' : ''},
        )
        shard.update_hash(
          model.model_key,
          id,
          {index_name => index_val},
        )
        shard.exec
      end
    end
  end

  sig { params(model: T.class_of(Redcord::Base), index_name: Symbol).void }
  def remove_index(model, index_name)
    model.redis.each_shard do |shard|
      if shard.sismember("#{model.model_key}:index_attrs", index_name)
        _remove_index_from_attr_set(
          model_key: model.model_key,
          shard: shard,
          attr_set_name: 'index_attrs',
          index_name: index_name,
        )

        shard.scan_each(match: "#{model.model_key}:#{index_name}:*") { |key| _del_set(shard, key) }
      elsif shard.sismember("#{model.model_key}:range_index_attrs", index_name)
        _remove_index_from_attr_set(
          model_key: model.model_key,
          shard: shard,
          attr_set_name: 'range_index_attrs',
          index_name: index_name,
        )

        attr_set = "#{model.model_key}:#{index_name}"
        nil_attr_set = "#{attr_set}:"

        _del_set(shard, nil_attr_set)
        _del_zset(shard, attr_set)
      else
        raise(
          Redcord::AttributeNotIndexed,
          "#{index_name} is not an indexed attribute.",
        )
      end
    end
  end

  sig {
    params(
      model_key: String,
      shard: Redcord::RedisShard,
      attr_set_name: String,
      index_name: Symbol,
    ).void
  }
  def _remove_index_from_attr_set(model_key:, shard:, attr_set_name:, index_name:)
    shard.srem("#{model_key}:#{attr_set_name}", index_name)
  end

  sig { params(shard: Redcord::RedisShard, key: String).void }
  def _del_set(shard, key)
    # Use SPOP here to minimize blocking
    loop do
      break unless shard.spop(key)
    end

    shard.del(key)
  end

  sig { params(shard: Redcord::RedisShard, key: String).void }
  def _del_zset(shard, key)
    # ZPOPMIN might not be avaliable on old redis servers
    shard.zscan_each(match: key) do |id, _|
      shard.zrem(key, id)
    end

    shard.del(key)
  end
end
