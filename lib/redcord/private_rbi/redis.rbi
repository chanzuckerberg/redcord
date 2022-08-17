# typed: ignore

class Redcord::Redis < Redis
  extend T::Sig

  sig do
    params(
      key: T.any(String, Symbol),
      args: T::Hash[T.untyped, T.untyped],
      ttl: T.nilable(Integer),
      index_attrs: T::Array[Symbol],
      range_index_attrs: T::Array[Symbol],
      custom_index_attrs: T::Hash[Symbol, T::Array],
      hash_tag: T.nilable(String),
    ).returns(String)
  end
  def create_hash_returning_id(key, args, ttl:, index_attrs:, range_index_attrs:, custom_index_attrs:, hash_tag: nil)
  end

  sig do
    params(
      model: String,
      id: String,
      args: T::Hash[T.untyped, T.untyped],
      ttl: T.nilable(Integer),
      index_attrs: T::Array[Symbol],
      range_index_attrs: T::Array[Symbol],
      custom_index_attrs: T::Hash[Symbol, T::Array],
      hash_tag: T.nilable(String),
    ).void
  end
  def update_hash(model, id, args, ttl:, index_attrs:, range_index_attrs:, custom_index_attrs:, hash_tag:)
  end

  sig do
    params(
      model: String,
      id: String,
      index_attrs: T::Array[Symbol],
      range_index_attrs: T::Array[Symbol],
      custom_index_attrs: T::Hash[Symbol, T::Array],
    ).returns(Integer)
  end
  def delete_hash(model, id, index_attrs:, range_index_attrs:, custom_index_attrs:)
  end

  sig do
    params(
      model: String,
      query_conditions: T::Hash[T.untyped, T.untyped],
      index_attrs: T::Array[Symbol],
      range_index_attrs: T::Array[Symbol],
      select_attrs: T::Set[Symbol],
      custom_index_attrs: T::Array[Symbol],
      hash_tag: T.nilable(String),
      custom_index_name: T.nilable(Symbol),
    ).returns(T::Hash[Integer, T::Hash[T.untyped, T.untyped]])
  end
  def find_by_attr(
        model,
        query_conditions,
        select_attrs: Set.new,
        index_attrs:,
        range_index_attrs:,
        custom_index_attrs: Array.new,
        hash_tag: nil,
        custom_index_name: nil
      )
  end

  sig do
    params(
      model: String,
      query_conditions: T::Hash[T.untyped, T.untyped],
      index_attrs: T::Array[Symbol],
      range_index_attrs: T::Array[Symbol],
      custom_index_attrs: T::Array[Symbol],
      hash_tag: T.nilable(String),
      custom_index_name: T.nilable(Symbol),
    ).returns(Integer)
  end
  def find_by_attr_count(
        model,
        query_conditions,
        index_attrs:,
        range_index_attrs:,
        custom_index_attrs: Array.new,
        hash_tag: nil,
        custom_index_name: nil
      )
  end

  def scan_each_shard(key, &blk)
  end

  private

  def run_script(script_name, *args)
  end

  sig { params(query_conditions: T::Hash[T.untyped, T.untyped], partial_order: T::Array[Symbol]).returns(T::Array[T.untyped]) }
  def flatten_with_partial_sort(query_conditions, partial_order)
  end
end
