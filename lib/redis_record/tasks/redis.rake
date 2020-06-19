# typed: strict
require 'yarr/migration/version'
require 'yarr/migration/migrator'

db_namespace = namespace :redis do
  task migrate: :environment do
    $stdout.sync = true
    migration_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    puts [
      'redis',
      'direction',
      'version',
      'migration',
      'duration',
    ].map { |str| str.ljust(30) }.join("\t")

    local_versions = RedisRecord::Migration::Version.new.all
    RedisRecord::Base.configurations[Rails.env].each do |model, config|
      redis = Redis.new(**(config.symbolize_keys))
      remote_versions = RedisRecord::Migration::Version.new(redis: redis).all
      (local_versions - remote_versions).sort.each do |version|
        RedisRecord::Migration::Migrator.migrate(
          redis: redis,
          version: version,
          direction: :up,
        )
      end
    end

    migration_end = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    puts "\nFinished in #{(migration_end - migration_start).round(3)} seconds"
  end
end
