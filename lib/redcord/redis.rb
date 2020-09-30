# typed: true
require 'digest'
require 'redis'
require 'securerandom'

class Redcord::Redis < Redis
  extend T::Sig

  sig do
    params(
      key: T.any(String, Symbol),
      args: T::Hash[T.untyped, T.untyped],
      ttl: T.nilable(Integer),
      index_attrs: T::Array[Symbol],
      range_index_attrs: T::Array[Symbol],
      hash_tag: T.nilable(String),
    ).returns(String)
  end
  def create_hash_returning_id(key, args, ttl:, index_attrs:, range_index_attrs:, hash_tag: nil)
    Redcord::Base.trace(
      'redcord_redis_create_hash_returning_id',
      model_name: key,
    ) do
      id = "#{SecureRandom.uuid}#{hash_tag}"
      run_script(
        :create_hash,
        keys: [id, hash_tag],
        argv: [key, ttl, index_attrs.size, range_index_attrs.size] + index_attrs + range_index_attrs + args.to_a.flatten,
      )
      id
    end
  end

  sig do
    params(
      model: String,
      id: String,
      args: T::Hash[T.untyped, T.untyped],
      ttl: T.nilable(Integer),
      index_attrs: T::Array[Symbol],
      range_index_attrs: T::Array[Symbol],
      hash_tag: T.nilable(String),
    ).void
  end
  def update_hash(model, id, args, ttl:, index_attrs:, range_index_attrs:, hash_tag:)
    Redcord::Base.trace(
      'redcord_redis_update_hash',
      model_name: model,
    ) do
      run_script(
        :update_hash,
        keys: [id, hash_tag],
        argv: [model, ttl, index_attrs.size, range_index_attrs.size] + index_attrs + range_index_attrs + args.to_a.flatten,
      )
    end
  end

  sig do
    params(
      model: String,
      id: String,
      index_attrs: T::Array[Symbol],
      range_index_attrs: T::Array[Symbol],
    ).returns(Integer)
  end
  def delete_hash(model, id, index_attrs:, range_index_attrs:)
    Redcord::Base.trace(
      'redcord_redis_delete_hash',
      model_name: model,
    ) do
      run_script(
        :delete_hash,
        keys: [id, id.match(/\{.*\}$/)&.send(:[], 0)],
        argv: [model, index_attrs.size, range_index_attrs.size] + index_attrs + range_index_attrs,
      )
    end
  end

  sig do
    params(
      model: String,
      query_conditions: T::Hash[T.untyped, T.untyped],
      select_attrs: T::Set[Symbol],
      index_attrs: T::Array[Symbol],
      range_index_attrs: T::Array[Symbol],
      hash_tag: T.nilable(String),
    ).returns(T::Hash[Integer, T::Hash[T.untyped, T.untyped]])
  end
  def find_by_attr(model, query_conditions, select_attrs=Set.new, index_attrs:, range_index_attrs:, hash_tag: nil)
    Redcord::Base.trace(
      'redcord_redis_find_by_attr',
      model_name: model,
    ) do
      conditions = query_conditions.to_a.flatten
      res = run_script(
        :find_by_attr,
        keys: [hash_tag],
        argv: [model, index_attrs.size, range_index_attrs.size, conditions.size] + index_attrs + range_index_attrs + conditions + select_attrs.to_a.flatten
      )
      # The Lua script will return this as a flattened array.
      # Convert the result into a hash of {id -> model hash}
      res_hash = res.each_slice(2)
      res_hash.map { |key, val| [key, val.each_slice(2).to_h] }.to_h
    end
  end

  sig do
    params(
      model: String,
      query_conditions: T::Hash[T.untyped, T.untyped],
      index_attrs: T::Array[Symbol],
      range_index_attrs: T::Array[Symbol],
      hash_tag: T.nilable(String),
    ).returns(Integer)
  end
  def find_by_attr_count(model, query_conditions, index_attrs:, range_index_attrs:, hash_tag: nil)
    Redcord::Base.trace(
      'redcord_redis_find_by_attr_count',
      model_name: model,
    ) do
      run_script(
        :find_by_attr_count,
        keys: [hash_tag],
        argv: [model, index_attrs.size, range_index_attrs.size] + index_attrs + range_index_attrs + query_conditions.to_a.flatten,
      )
    end
  end

  private

  def run_script(script_name, *args)
    # Use EVAL when a redis shard has not loaded the script before
    hash_var_name = :"@script_sha_#{script_name}"
    hash = instance_variable_get(hash_var_name)
    evalsha(hash, *args)
  rescue Redis::CommandError => e
    if e.message != 'NOSCRIPT No matching script. Please use EVAL.'
      raise e
    end

    script_content = Redcord::LuaScriptReader.read_lua_script(script_name.to_s)
    instance_variable_set(hash_var_name, Digest::SHA1.hexdigest(script_content))
    self.eval(script_content, *args)
  end
end
