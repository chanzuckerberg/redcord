# typed: strict
class RedisRecord::Migration::Version
  MIGRATION_VERSIONS_REDIS_KEY = 'RedisRecord:__migration_versions__'

  sig { params(redis: T.nilable(Redis)).void }
  def initialize(redis: nil)
    @redis = T.let(redis, T.nilable(Redis))
  end

  sig { returns(T.nilable(String)) }
  def current
    all.sort.last
  end

  sig { returns(T::Array[String]) }
  def all
    if @redis
      remote_versions
    else
      local_versions
    end
  end

  private

  sig { returns(T::Array[String]) }
  def local_versions
    RedisRecord::Migration::Migrator.migration_files.map do |filename|
      fields = RedisRecord::Migration::Migrator.parse_migration_filename(filename)
      fields[0]
    end
  end

  sig { returns(T::Array[String]) }
  def remote_versions
    T.must(@redis).smembers(MIGRATION_VERSIONS_REDIS_KEY)
  end
end
