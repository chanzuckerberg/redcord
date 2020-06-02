# typed: strict
module RedisRecord::ServerScripts
  # Extending T::Sig in Redis instances will cause runtime errors. Hence
  # no real runtime sig decorators on instance methods for the following
  # methods.
  extend T::Sig::WithoutRuntime

  sig do
    params(
      key: T.any(String, Symbol),
      args: T::Hash[T.untyped, T.untyped],
    ).returns(Integer)
  end
  def create_hash_returning_id(key, args)
    evalsha(
      T.must(redis_record_server_script_shas[:create_hash_returning_id]),
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
      T.must(redis_record_server_script_shas[:update_hash]),
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
      T.must(redis_record_server_script_shas[:delete_hash]),
      keys: [model, id]
    )
  end

  sig do (
    params(
      model: String,
      attrs: T::Hash[T.untyped, T.untyped]
      ).returns(T::Hash[Integer, T::Hash[T.untyped, T.untyped]])
  )
  end
  def find_by_attr(model, attrs)
    res = evalsha(
      T.must(redis_record_server_script_shas[:find_by_attr]),
      keys: [model],
      argv: attrs.to_a.flatten,
    )
    # The Lua script will return this as a flattened array.
    # Convert the result into a hash of {id -> model hash}
    res_hash = res.each_slice(2)
    res_hash.map { |key, val| [key.to_i, val.each_slice(2).to_h] }.to_h
  end
end
