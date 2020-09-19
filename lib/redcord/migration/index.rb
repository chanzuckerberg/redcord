# frozen_string_literal: true

# typed: strict

module Redcord::Migration::Index
  extend T::Sig

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
    # Use ZPOPMIN here to minimize blocking
    loop do
      break unless model.redis.zpopmin(key)
    end

    model.redis.del(key)
  rescue Redis::CommandError
    # zpopmin might not be avaliable on old redis servers
    model.redis.del(key)
  end
end
