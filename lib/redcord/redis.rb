# typed: ignore
require 'digest'
require 'redis'
require 'securerandom'

class Redcord::Redis < Redis
  def create_hash_returning_id(key, args, ttl:, index_attrs:, range_index_attrs:, custom_index_attrs:, hash_tag: nil)
    Redcord::Base.trace(
      'redcord_redis_create_hash_returning_id',
      model_name: key,
    ) do
      id = "#{SecureRandom.uuid}#{hash_tag}"
      custom_index_attrs_flat = custom_index_attrs.inject([]) do |result, (index_name, attrs)|
        result << index_name
        result << attrs.size
        result + attrs
      end
      run_script(
        :create_hash,
        keys: [id, hash_tag],
        argv: [key, ttl, index_attrs.size, range_index_attrs.size, custom_index_attrs_flat.size] + 
          index_attrs + range_index_attrs + custom_index_attrs_flat + args.to_a.flatten,
      )
      id
    end
  end

  def update_hash(model, id, args, ttl:, index_attrs:, range_index_attrs:, custom_index_attrs:, hash_tag:)
    Redcord::Base.trace(
      'redcord_redis_update_hash',
      model_name: model,
    ) do
      custom_index_attrs_flat = custom_index_attrs.inject([]) do |result, (index_name, attrs)|
        if !(args.keys.to_set & attrs.to_set).empty?
          result << index_name
          result << attrs.size
          result + attrs
        else
          result
        end
      end
      run_script(
        :update_hash,
        keys: [id, hash_tag],
        argv: [model, ttl, index_attrs.size, range_index_attrs.size, custom_index_attrs_flat.size] +
          index_attrs + range_index_attrs + custom_index_attrs_flat + args.to_a.flatten,
      )
    end
  end

  def delete_hash(model, id, index_attrs:, range_index_attrs:, custom_index_attrs:)
    Redcord::Base.trace(
      'redcord_redis_delete_hash',
      model_name: model,
    ) do
      custom_index_names = custom_index_attrs.keys
      run_script(
        :delete_hash,
        keys: [id, id.match(/\{.*\}$/)&.send(:[], 0)],
        argv: [model, index_attrs.size, range_index_attrs.size] + index_attrs + range_index_attrs + custom_index_names,
      )
    end
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
    Redcord::Base.trace(
      'redcord_redis_find_by_attr',
      model_name: model,
    ) do
      conditions = flatten_with_partial_sort(query_conditions.clone, custom_index_attrs)
      res = run_script(
        :find_by_attr,
        keys: [hash_tag],
        argv: [model, custom_index_name, index_attrs.size, range_index_attrs.size, custom_index_attrs.size, conditions.size] + 
          index_attrs + range_index_attrs + custom_index_attrs + conditions + select_attrs.to_a.flatten
      )
      # The Lua script will return this as a flattened array.
      # Convert the result into a hash of {id -> model hash}
      res_hash = res.each_slice(2)
      res_hash.map { |key, val| [key, val.each_slice(2).to_h] }.to_h
    end
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
    Redcord::Base.trace(
      'redcord_redis_find_by_attr_count',
      model_name: model,
    ) do
      conditions = flatten_with_partial_sort(query_conditions.clone, custom_index_attrs)
      run_script(
        :find_by_attr_count,
        keys: [hash_tag],
        argv: [model, custom_index_name, index_attrs.size, range_index_attrs.size, custom_index_attrs.size] +
          index_attrs + range_index_attrs + custom_index_attrs + conditions
      )
    end
  end

  def scan_each_shard(key, &blk)
    clients = instance_variable_get(:@client)
      &.instance_variable_get(:@node)
      &.instance_variable_get(:@clients)
      &.values

    if clients.nil?
      scan_each(match: key, &blk)
    else
      clients.each do |client|
        cursor = 0
        loop do
          cursor, keys = client.call([:scan, cursor, 'match', key])
          keys.each(&blk)
          break if cursor == "0"
        end
      end
    end
  end

  private

  def run_script(script_name, *args)
    # Use EVAL when a redis shard has not loaded the script before
    hash_var_name = :"@script_sha_#{script_name}"
    hash = instance_variable_get(hash_var_name)

    begin
      return evalsha(hash, *args) if hash
    rescue Redis::CommandError => e
      if e.message != 'NOSCRIPT No matching script. Please use EVAL.'
        raise e
      end
    end

    script_content = Redcord::LuaScriptReader.read_lua_script(script_name.to_s)
    instance_variable_set(hash_var_name, Digest::SHA1.hexdigest(script_content))
    self.eval(script_content, *args)
  end

  # When using custom index: On Lua side script expects query conditions sorted 
  # in the order of appearance of attributes in specified index
  def flatten_with_partial_sort(query_conditions, partial_order)
    conditions = partial_order.inject([]) do |result, attr|
      if !query_conditions[attr].nil?
        result << attr << query_conditions.delete(attr)
      end
      result.flatten
    end
    conditions += query_conditions.to_a.flatten
  end
end
