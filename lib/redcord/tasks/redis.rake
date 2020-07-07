# typed: strict
require 'redcord/migration/version'
require 'redcord/migration/migrator'

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

    local_versions = Redcord::Migration::Version.new.all
    Redcord::Base.configurations[Rails.env].each do |model, config|
      redis = Redis.new(**(config.symbolize_keys))
      remote_versions = Redcord::Migration::Version.new(redis: redis).all
      (local_versions - remote_versions).sort.each do |version|
        Redcord::Migration::Migrator.migrate(
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
