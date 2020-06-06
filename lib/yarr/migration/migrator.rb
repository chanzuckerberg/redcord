# typed: strict
class RedisRecord::Migration::Migrator
  sig { params(redis: Redis).returns(T::Boolean) }
  def self.need_to_migrate?(redis)
    local_version = RedisRecord::Migration::Version.new
    remote_version = RedisRecord::Migration::Version.new(redis: redis)
    !(local_version.all - remote_version.all).empty?
  end

  sig { params(redis: Redis, version: String, direction: Symbol).void }
  def self.migrate(redis:, version:, direction:)
    migration = load_version(version)
    print [
      T.must("#{redis.inspect.match('(redis://.*)>')[1]}"[0...30]),
      direction.to_s.upcase,
      version,
      T.must(migration.name).underscore.humanize,
    ].map { |str| str.ljust(30) }.join("\t")

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    migration.new(redis).send(direction)
    if direction == :up
      redis.sadd(
        RedisRecord::Migration::Version::MIGRATION_VERSIONS_REDIS_KEY,
        version,
      )
    else
      redis.srem(
        RedisRecord::Migration::Version::MIGRATION_VERSIONS_REDIS_KEY,
        version,
      )
    end
    end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    puts "\t#{(end_time - start_time) * 1000.0.round(3)} ms"
  end

  private

  sig { params(version: String).returns(T.class_of(RedisRecord::Migration)) }
  def self.load_version(version)
    file = T.must(migration_files.select { |f| f.match(version) }.first)
    require(File.expand_path(file))
    underscore_const_name = parse_migration_filename(file)[1]
    Object.const_get(underscore_const_name.camelize)
  end

  MIGRATION_FILENAME_REGEX = /\A([0-9]+)_([_a-z0-9]*)\.?([_a-z0-9]*)?\.rb\z/

  @@migrations_paths = T.let(
    ['db/redisrecord/migrate'],
    T::Array[String],
  )

  sig { returns(T::Array[String]) }
  def self.migrations_paths
    @@migrations_paths
  end

  sig { returns(T::Array[String]) }
  def self.migration_files
    paths = migrations_paths
    # Use T.unsafe to workaround sorbet: splat the paths
    T.unsafe(Dir)[*paths.flat_map { |path| "#{path}/**/[0-9]*_*.rb" }]
  end


  sig { params(filename: String).returns([String, String, String]) }
  def self.parse_migration_filename(filename)
    T.unsafe(File.basename(filename).scan(MIGRATION_FILENAME_REGEX).first)
  end
end
