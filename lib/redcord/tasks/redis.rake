require 'redcord/migration/version'
require 'redcord/migration/migrator'
require 'redcord/vacuum_helper'

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

  task :vacuum, [:model_name] => :environment do |t, args|
    desc "Vacuum index attributes for stale ids on a Redcord model"
    $stdout.sync = true
    model_name = args[:model_name]
    puts "Attempting to vacuum the index attributes of the Redcord model: #{model_name}"
    vacuum_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    Redcord::VacuumHelper.vacuum(Object.const_get(args[:model_name]))
    vacuum_end = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    puts "Finished vacuuming #{model_name} in #{(vacuum_end - vacuum_start).round(3)} seconds"
  rescue NameError => e
    raise StandardError.new("#{args[:model_name]} is not a valid Redcord model.")
  end
end
