# frozen_string_literal: true


class Redcord::Migration::Version
  MIGRATION_VERSIONS_REDIS_KEY = 'Redcord:__migration_versions__'

  def initialize(redis: nil)
    @redis = redis
  end

  def current
    all.sort.last
  end

  def all
    if @redis
      remote_versions
    else
      local_versions
    end
  end

  private

  def local_versions
    Redcord::Migration::Migrator.migration_files.map do |filename|
      fields = Redcord::Migration::Migrator.parse_migration_filename(filename)
      fields[0]
    end
  end

  def remote_versions
    T.must(@redis).smembers(MIGRATION_VERSIONS_REDIS_KEY)
  end
end
