# frozen_string_literal: true

# typed: strict

module Redcord::VacuumHelper
  extend T::Sig
  extend T::Helpers

  sig { params(model: T.class_of(Redcord::Base)).void }
  def self.vacuum(model)
    model.class_variable_get(:@@index_attributes).each do |index_attr|
      puts "Vacuuming index attribute: #{index_attr}"
      _vacuum_index_attribute(model, index_attr)
    end
    model.class_variable_get(:@@range_index_attributes).each do |range_index_attr|
      puts "Vacuuming range index attribute: #{range_index_attr}"
      _vacuum_range_index_attribute(model, range_index_attr)
    end
  end

  sig { params(model: T.class_of(Redcord::Base), index_attr: Symbol).void }
  def self._vacuum_index_attribute(model, index_attr)
    # Scan through all index attribute values by matching on Redcord:Model:index_attr:*
    model.redis.each_shard do |shard|
      shard.scan_each(match: "#{model.model_key}:#{index_attr}:*") do |key|
        _remove_stale_ids_from_set(model.model_key, shard, key)
      end
    end
  end

  sig { params(model: T.class_of(Redcord::Base), range_index_attr: Symbol).void }
  def self._vacuum_range_index_attribute(model, range_index_attr)
    model.redis.each_shard do |shard|
      range_index_set_key = "#{model.model_key}:#{range_index_attr}"
      _remove_stale_ids_from_sorted_set(model.model_key, shard, range_index_set_key)

      # Handle nil values for range index attributes, which are stored in a normal
      # set at Redcord:Model:range_index_attr:
      range_index_set_nil_key = "#{range_index_set_key}:"
      _remove_stale_ids_from_set(model.model_key, shard, range_index_set_nil_key)
    end
  end

  sig { params(model_key: String, shard: Redcord::RedisShard, set_key: String).void }
  def self._remove_stale_ids_from_set(model_key, shard, set_key)
    shard.sscan_each(set_key) do |id|
      if !shard.exists?("#{model_key}:id:#{id}")
        shard.srem(set_key, id)
      end
    end
  end

  sig { params(model_key: String, shard: Redcord::RedisShard, sorted_set_key: String).void }
  def self._remove_stale_ids_from_sorted_set(model_key, shard, sorted_set_key)
    shard.zscan_each(sorted_set_key) do |id, _|
      if !shard.exists?("#{model_key}:id:#{id}")
        shard.zrem(sorted_set_key, id)
      end
    end
  end
end
