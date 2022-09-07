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
  methods = Set.new(Redcord::Redis.instance_methods(false) + Redis.instance_methods(false))
  methods.each do |method_name|
    define_method method_name do |*args, **kwargs, &blk|
      @connection_pool.with do |redis|
        redis.send(method_name, *args, **kwargs, &blk)
      end
    end
  end

  def method_missing(method_name, *args, **kwargs, &blk)
    @connection_pool.with do |redis|
      redis.send(method_name, *args, **kwargs, &blk)
    end
  end
end
