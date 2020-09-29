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
      hash_tag: T.nilable(String),
    ).returns(String)
  end
  def create_hash_returning_id(key, args, hash_tag=nil)
    Redcord::Base.trace(
      'redcord_redis_create_hash_returning_id',
      model_name: key,
    ) do
      id = "#{SecureRandom.uuid}{#{hash_tag}}"
      run_script(
        self.class.server_script_shas[:create_hash],
        keys: [key, id],
        argv: args.to_a.flatten,
      )
      id
    end
  end

  sig do
    params(
      model: String,
      id: String,
      args: T::Hash[T.untyped, T.untyped],
      hash_tag: T.nilable(String),
    ).void
  end
  def update_hash(model, id, args, hash_tag=nil)
    Redcord::Base.trace(
      'redcord_redis_update_hash',
      model_name: model,
    ) do
      run_script(
        self.class.server_script_shas[:update_hash],
        keys: [model, id, "{#{hash_tag}}"],
        argv: args.to_a.flatten,
      )
    end
  end

  sig do
    params(
      model: String,
      id: String, 
      hash_tag: T.nilable(String),
    ).returns(Integer)
  end
  def delete_hash(model, id, hash_tag=nil)
    Redcord::Base.trace(
      'redcord_redis_delete_hash',
      model_name: model,
    ) do
      run_script(
        self.class.server_script_shas[:delete_hash],
        keys: [model, id, "{#{hash_tag}}"]
      )
    end
  end

  sig do
    params(
      model: String,
      query_conditions: T::Hash[T.untyped, T.untyped],
      select_attrs: T::Set[Symbol],
      hash_tag: T.nilable(String),
    ).returns(T::Hash[Integer, T::Hash[T.untyped, T.untyped]])
  end
  def find_by_attr(model, query_conditions, select_attrs=Set.new, hash_tag=nil)
    Redcord::Base.trace(
      'redcord_redis_find_by_attr',
      model_name: model,
    ) do
      res = run_script(
        self.class.server_script_shas[:find_by_attr],
        keys: [model] + query_conditions.to_a.flatten + ["{#{hash_tag}}"],
        argv: select_attrs.to_a.flatten
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
      hash_tag: T.nilable(String),
    ).returns(Integer)
  end
  def find_by_attr_count(model, query_conditions, hash_tag=nil)
    Redcord::Base.trace(
      'redcord_redis_find_by_attr_count',
      model_name: model,
    ) do
      run_script(
        self.class.server_script_shas[:find_by_attr_count],
        keys: [model] + query_conditions.to_a.flatten + ["{#{hash_tag}}"],
      )
    end
  end

  private

  def run_script(script_name, *args)
    hash = instance_variable_get(script_name)
    evalsha(hash, *args)
  rescue Redis::CommandError => e
    if e.message != 'NOSCRIPT No matching script. Please use EVAL.'
      raise e
    end

    script_content = Redcord::LuaScriptReader.read_lua_script(script_name.to_s)
    instance_variable_set(script_name, Digest::SHA1.hexdigest(script_content))
    self.eval(script_content, *args)
  end
end
