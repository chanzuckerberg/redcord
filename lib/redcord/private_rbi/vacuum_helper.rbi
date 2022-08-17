# typed: true

module Redcord::VacuumHelper
  extend T::Sig
  extend T::Helpers

  sig { params(model: T.class_of(Redcord::Base)).void }
  def self.vacuum(model)
  end

  sig { params(model: T.class_of(Redcord::Base), index_attr: Symbol).void }
  def self._vacuum_index_attribute(model, index_attr)
  end

  sig { params(model: T.class_of(Redcord::Base), range_index_attr: Symbol).void }
  def self._vacuum_range_index_attribute(model, range_index_attr)
  end

  sig { params(model: T.class_of(Redcord::Base), index_name: Symbol).void }
  def self._vacuum_custom_index(model, index_name)
  end

  sig { params(model: T.class_of(Redcord::Base), set_key: String).void }
  def self._remove_stale_ids_from_set(model, set_key)
  end

  sig { params(model: T.class_of(Redcord::Base), sorted_set_key: String).void }
  def self._remove_stale_ids_from_sorted_set(model, sorted_set_key)
  end

  sig { params(model: T.class_of(Redcord::Base), hash_tag: String, index_name: Symbol).void }
  def self._remove_stale_records_from_custom_index(model, hash_tag, index_name)
  end
end
