# frozen_string_literal: true

# typed: strict

module Redcord::VacuumHelper
  extend T::Sig
  extend T::Helpers

  sig { params(model: T.class_of(Redcord::Base)).void }
  def self.vacuum(model)
    model.class_variable_get(:@@index_attributes).each do |index_attr|
      vacuum_index_attribute(model, index_attr)
    end
    model.class_variable_get(:@@range_index_attributes).each do |range_index_attr|
      vacuum_range_index_attribute(model, range_index_attr)
    end
  end

  sig { params(model: T.class_of(Redcord::Base), index_attr: Symbol).void }
  def self.vacuum_index_attribute(model, index_attr)
    # Scan through all index attribute values by matching on Redcord:Model:index_attr:*
    model.redis.scan_each(match: "#{model.model_key}:#{index_attr}:*") do |key|
    expire_stale_ids_from_set(model, key)
    end
  end

  sig { params(model: T.class_of(Redcord::Base), range_index_attr: Symbol).void }
  def self.vacuum_range_index_attribute(model, range_index_attr)
    range_index_set_key = "#{model.model_key}:#{range_index_attr}"
    expire_stale_ids_from_sorted_set(model, range_index_set_key)

    # Handle nil values for range index attributes, which are stored in a normal
    # set at Redcord:Model:range_index_attr:
    range_index_set_nil_key = "#{range_index_set_key}:"
    expire_stale_ids_from_set(model, range_index_set_nil_key)
  end

  sig { params(model: T.class_of(Redcord::Base), set_key: String).void }
  def self.expire_stale_ids_from_set(model, set_key)
    model.redis.sscan_each(set_key) do |id|
      if !model.redis.exists?("#{model.model_key}:id:#{id}")
        model.redis.srem(set_key, id)
      end
    end
  end

  sig { params(model: T.class_of(Redcord::Base), sorted_set_key: String).void }
  def self.expire_stale_ids_from_sorted_set(model, sorted_set_key)
    model.redis.zscan_each(sorted_set_key) do |id, _|
      if !model.redis.exists?("#{model.model_key}:id:#{id}")
        model.redis.zrem(sorted_set_key, id)
      end
    end
  end
end
