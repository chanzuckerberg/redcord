# typed: strict
require 'redis'

# TODO: Rename Redcord::PreparedRedis -> Redcord::Redis
class Redcord::PreparedRedis < Redis
  extend T::Sig

  sig do
    params(
      key: T.any(String, Symbol),
      args: T::Hash[T.untyped, T.untyped],
    ).returns(Integer)
  end
  def create_hash_returning_id(key, args)
    evalsha(
      self.class.server_script_shas[:create_hash_returning_id],
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
      self.class.server_script_shas[:update_hash],
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
      self.class.server_script_shas[:delete_hash],
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
      self.class.server_script_shas[:find_by_attr],
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
      self.class.server_script_shas[:find_by_attr_count],
      keys: [model] + query_conditions.to_a.flatten,
    )
  end

  sig { void }
  def load_server_scripts!
    script_names = Dir['lib/redcord/server_scripts/*.lua'].map do |filename|
      # lib/redcord/server_scripts/find_by_attr.erb.lua -> find_by_attr
      T.must(filename.split('/').last).split('.').first&.to_sym
    end

    res = pipelined do
      script_names.each do |script_name|
        script(
          :load,
          Redcord::LuaScriptReader.read_lua_script(script_name.to_s),
        )
      end
    end

    if self.class.class_variable_get(:@@server_script_shas).nil?
      self.class.class_variable_set(
        :@@server_script_shas,
        script_names.zip(res).to_h
      )
    end
  end

  @@server_script_shas = T.let(nil, T.nilable(T::Hash[Symbol, String]))

  sig { returns(T::Hash[Symbol, String]) }
  def self.server_script_shas
    T.must(@@server_script_shas)
  end

  sig { void }
  def self.load_server_scripts!
    Redcord::Base.configurations[Rails.env].each do |_, config|
      new(**(config.symbolize_keys)).load_server_scripts!
    end
  end
end
