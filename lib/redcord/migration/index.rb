# frozen_string_literal: true

# typed: strict

module Redcord::Migration::Index
  extend T::Sig

  sig { params(model: T.class_of(Redcord::Base), index_name: Symbol).void }
  def add_index(model, index_name)
    if model.class_variable_get(:@@range_index_attributes).include?(index_name)
      model.redis.sadd("#{model.model_key}:range_index_attrs", index_name.to_s)
    elsif model.class_variable_get(:@@index_attributes).include?(index_name)
      model.redis.sadd("#{model.model_key}:index_attrs", index_name.to_s)
    else
      raise(
        Redcord::AttributeNotIndexed,
        "#{index_name} is not an indexed attribute.",
      )
    end

    # Loop through existing records and build the index
    model.redis.scan_each(match: "#{model.model_key}:id:*") do |key|
      index_val = model.redis.hmget(key, index_name.to_s).first
      id = key.split(':').last.to_i

      # Force refresh on the updated index attribute. Use multi to ensure
      # consistency incase this migration failed in the middle
      model.redis.multi
      model.redis.update_hash(
        model.model_key,
        id,
        {index_name => index_val.empty? ? 'redcord_temp_val' : ''},
      )
      model.redis.update_hash(
        model.model_key,
        id,
        {index_name => index_val},
      )
      model.redis.exec
    end
  end

  sig { params(model: T.class_of(Redcord::Base), index_name: Symbol).void }
  def remove_index(model, index_name)
    if model.redis.sismember("#{model.model_key}:index_attrs", index_name)
      _remove_index_from_attr_set(
        model: model,
        attr_set_name: 'index_attrs',
        index_name: index_name,
      )

      model.redis.scan_each(match: "#{model.model_key}:#{index_name}:*") { |key| _del_set(model, key) }
    elsif model.redis.sismember("#{model.model_key}:range_index_attrs", index_name)
      _remove_index_from_attr_set(
        model: model,
        attr_set_name: 'range_index_attrs',
        index_name: index_name,
      )

      attr_set = "#{model.model_key}:#{index_name}"
      nil_attr_set = "#{attr_set}:"

      _del_set(model, nil_attr_set)
      _del_zset(model, attr_set)
    else
      raise(
        Redcord::AttributeNotIndexed,
        "#{index_name} is not an indexed attribute.",
      )
    end
  end

  sig {
    params(
      model: T.class_of(Redcord::Base),
      attr_set_name: String,
      index_name: Symbol,
    ).void
  }
  def _remove_index_from_attr_set(model:, attr_set_name:, index_name:)
    model.redis.srem("#{model.model_key}:#{attr_set_name}", index_name)
  end

  sig { params(model: T.class_of(Redcord::Base), key: String).void }
  def _del_set(model, key)
    # Use SPOP here to minimize blocking
    loop do
      break unless model.redis.spop(key)
    end

    model.redis.del(key)
  end

  sig { params(model: T.class_of(Redcord::Base), key: String).void }
  def _del_zset(model, key)
    # ZPOPMIN might not be avaliable on old redis servers
    model.redis.zscan_each(match: key) do |id, _|
      model.redis.zrem(key, id)
    end

    model.redis.del(key)
  end
end
