# frozen_string_literal: true

# typed: false

require 'active_support/core_ext/module'

require_relative 'redis_shard'

# Delegate existing methods to all shards
class Redcord::Redis
  def initialize(*args)
    @client = Redcord::RedisShard.new(*args)
  end

  def shards
    @client
      .instance_variable_get(:@client)
      &.instance_variable_get(:@node)
      &.instance_variable_get(:@clients)
      &.values || [@client]
  end

  def create_hash_returning_id(key, args)
    # Randomly place a new record on a shard
    shards.sample(1).first.create_hash_returning_id(key, args)
  end

  def update_hash(*args)
    each_shard { |shard| shard.update_hash(*args) }
  end

  def delete_hash(*args)
    each_shard { |shard| shard.delete_hash(*args) }
  end

  def find_by_attr(*args)
    records = {}
    each_shard { |shard| records.merge!(shard.find_by_attr(*args)) }
    records
  end

  def find_by_attr_count(*args)
    count = 0
    each_shard { |shard| count += shard.find_by_attr_count(*args) }
    count
  end

  def load_server_scripts!
    each_shard { |shard| shard.load_server_scripts! }
  end

  def hgetall(*args)
    res = nil
    each_shard { |shard| res ||= shard.hgetall(*args) }
    res
  end

  def hmget(*args)
    shards.hmget?(*args)
  end

  def exists?(*args)
    shards.exists?(*args)
  end

  def ping
    shards.ping
  end

  def self.server_script_shas
    Redcord::RedisShard.class_variable_get(:@@server_script_shas)
  end

  def self.load_server_scripts!
    Redcord::Base.configurations[Rails.env].each do |_, config|
      Redcord::RedisShard.new(**(config.symbolize_keys)).load_server_scripts!
    end
  end

  def each_shard(&blk)
    threads = shards.map do |shard|
      Thread.new do
        Thread.current.abort_on_exception = true
        Thread.current.report_on_exception = false

        blk.call(shard)
      end
    end

    threads.each { |t| t.join }
  end
end
