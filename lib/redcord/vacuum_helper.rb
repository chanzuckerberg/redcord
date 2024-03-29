# frozen_string_literal: true

# typed: strict

module Redcord::VacuumHelper
  extend T::Sig
  extend T::Helpers

  sig { params(model: T.class_of(Redcord::Base)).void }
  def self.vacuum(model)
    model.class_variable_get(:@@index_attributes).each do |index_attr|
      puts "Vacuuming index attribute: #{index_attr} for model: #{model.name}"
      _vacuum_index_attribute(model, index_attr)
    end
    model.class_variable_get(:@@range_index_attributes).each do |range_index_attr|
      puts "Vacuuming range index attribute: #{range_index_attr} for model: #{model.name}"
      _vacuum_range_index_attribute(model, range_index_attr)
    end
    model.class_variable_get(:@@custom_index_attributes).keys.each do |index_name|
      puts "Vacuuming custom index: #{index_name} for model: #{model.name}"
      _vacuum_custom_index(model, index_name)
    end
  end

  sig { params(model: T.class_of(Redcord::Base), index_attr: Symbol).void }
  def self._vacuum_index_attribute(model, index_attr)
    # Scan through all index attribute values by matching on Redcord:Model:index_attr:*
    model.redis.scan_each_shard("#{model.model_key}:#{index_attr}:*") do |key|
      _remove_stale_ids_from_set(model, key)
    end
  end

  sig { params(model: T.class_of(Redcord::Base), range_index_attr: Symbol).void }
  def self._vacuum_range_index_attribute(model, range_index_attr)
    key_suffix = model.shard_by_attribute.nil? ? nil : '{*}'
    range_index_set_key = "#{model.model_key}:#{range_index_attr}"
    range_index_set_nil_key = "#{range_index_set_key}:"

    # Handle nil values for range index attributes, which are stored in a normal
    # set at Redcord:Model:range_index_attr:
    model.redis.scan_each_shard("#{range_index_set_nil_key}#{key_suffix}") do |key|
      _remove_stale_ids_from_set(model, key)
    end

    model.redis.scan_each_shard("#{range_index_set_key}#{key_suffix}") do |key|
      _remove_stale_ids_from_sorted_set(model, key)
    end
  end

  sig { params(model: T.class_of(Redcord::Base), index_name: Symbol).void }
  def self._vacuum_custom_index(model, index_name)
    key_suffix = model.shard_by_attribute.nil? ? nil : '{*}'
    custom_index_content_key = "#{model.model_key}:custom_index:#{index_name}_content"

    model.redis.scan_each_shard("#{custom_index_content_key}#{key_suffix}") do |key|
      hash_tag = key.split(custom_index_content_key)[1] || ""
      _remove_stale_records_from_custom_index(model, hash_tag, index_name)
    end
  end

  sig { params(model: T.class_of(Redcord::Base), set_key: String).void }
  def self._remove_stale_ids_from_set(model, set_key)
    model.redis.sscan_each(set_key) do |id|
      if !model.redis.exists?("#{model.model_key}:id:#{id}")
        model.redis.srem(set_key, id)
      end
    end
  end

  sig { params(model: T.class_of(Redcord::Base), sorted_set_key: String).void }
  def self._remove_stale_ids_from_sorted_set(model, sorted_set_key)
    model.redis.zscan_each(sorted_set_key) do |id, _|
      if !model.redis.exists?("#{model.model_key}:id:#{id}")
        model.redis.zrem(sorted_set_key, id)
      end
    end
  end

  sig { params(model: T.class_of(Redcord::Base), hash_tag: String, index_name: Symbol).void }
  def self._remove_stale_records_from_custom_index(model, hash_tag, index_name)
    index_key = "#{model.model_key}:custom_index:#{index_name}#{hash_tag}"
    index_content_key = "#{model.model_key}:custom_index:#{index_name}_content#{hash_tag}"
    model.redis.hscan_each(index_content_key).each do |id, index_string|
      if !model.redis.exists?("#{model.model_key}:id:#{id}")
        model.redis.hdel(index_content_key, id)
        model.redis.zremrangebylex(index_key, "[#{index_string}", "[#{index_string}")
      end
    end
  end
end
