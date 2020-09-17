# typed: false
module Redcord::ServerScripts
  extend T::Sig

  sig do
    params(
      key: T.any(String, Symbol),
      args: T::Hash[T.untyped, T.untyped],
    ).returns(Integer)
  end
  def create_hash_returning_id(key, args)
    evalsha(
      T.must(redcord_server_script_shas[:create_hash_returning_id]),
      keys: [key],
      argv: args.to_a.flatten,
    ).to_i
  end

  sig do
    params(
      model: String,
      id: Integer,
      args: T::Hash[T.untyped, T.untyped],
    ).void
  end
  def update_hash(model, id, args)
    evalsha(
      T.must(redcord_server_script_shas[:update_hash]),
      keys: [model, id],
      argv: args.to_a.flatten,
    )
  end

  sig do
    params(
      model: String,
      id: Integer
    ).returns(Integer)
  end
  def delete_hash(model, id)
    evalsha(
      T.must(redcord_server_script_shas[:delete_hash]),
      keys: [model, id]
    )
  end

  sig do
    params(
      model: String,
      query_conditions: T::Hash[T.untyped, T.untyped],
      select_attrs: T::Set[Symbol]
    ).returns(T::Hash[Integer, T::Hash[T.untyped, T.untyped]])
  end
  def find_by_attr(model, query_conditions, select_attrs=Set.new)
    res = evalsha(
      T.must(redcord_server_script_shas[:find_by_attr]),
      keys: [model] + query_conditions.to_a.flatten,
      argv: select_attrs.to_a.flatten
    )
    # The Lua script will return this as a flattened array.
    # Convert the result into a hash of {id -> model hash}
    res_hash = res.each_slice(2)
    res_hash.map { |key, val| [key.to_i, val.each_slice(2).to_h] }.to_h
  end

  sig do
    params(
      model: String,
      query_conditions: T::Hash[T.untyped, T.untyped]
    ).returns(Integer)
  end
  def find_by_attr_count(model, query_conditions)
    evalsha(
      T.must(redcord_server_script_shas[:find_by_attr_count]),
      keys: [model] + query_conditions.to_a.flatten,
    )
  end

  sig do
    params(
      model_key: String,
      attribute: Symbol
    ).void
  end
  def vacuum_index_set(model_key, attribute)
    cursor = 0
    loop do
      cursor = evalsha(
        T.must(redcord_server_script_shas[:vacuum_index_set]),
        keys: [model_key],
        argv: [attribute, cursor]
      ).to_i
      break if cursor == 0
    end
  end

  sig do
    params(
      model_key: String,
      attribute: Symbol
    ).void
  end
  def vacuum_range_index_set(model_key, attribute)
    cursor = 0
    loop do
      cursor = evalsha(
        T.must(redcord_server_script_shas[:vacuum_range_index_set]),
        keys: [model_key],
        argv: [attribute, cursor]
      ).to_i
      break if cursor == 0
    end
  end
end
