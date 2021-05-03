# frozen_string_literal: true
require 'connection_pool'
require_relative 'redis'

class Redcord::ConnectionPool
  def initialize(pool_size:, timeout:, **client_options)
    @connection_pool = ::ConnectionPool.new(size: pool_size, timeout: timeout) do
      # Construct a new client every time the block gets called
      Redcord::Redis.new(**client_options, logger: Redcord::Logger.proxy)
    end
  end

  # Avoid method_missing when possible for better performance
  %i(create_hash_returning_id update_hash delete_hash find_by_attr find_by_attr_count ping).each do |method_name|
    define_method method_name do |*args, &blk|
      @connection_pool.with do |redis|
        redis.send(method_name, *args, &blk)
      end
    end
  end

  def method_missing(method_name, *args, &blk)
    @connection_pool.with do |redis|
      redis.send(method_name, *args, &blk)
    end
  end
end
