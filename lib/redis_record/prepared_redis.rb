# typed: strict
class RedisRecord::PreparedRedis < Redis
  include RedisRecord::ServerScripts

  sig { returns(T::Hash[Symbol, String]) }
  def redis_record_server_script_shas
    instance_variable_get(:@_redis_record_server_script_shas)
  end

  sig { params(shas: T::Hash[Symbol, String]).void }
  def redis_record_server_script_shas=(shas)
    instance_variable_set(:@_redis_record_server_script_shas, shas)
  end
end
