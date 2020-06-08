# typed: strict
require 'sorbet-runtime'

module RedisRecord
  if defined?(Rails)
    require 'yarr/base'
  end
  class Migration
    if defined?(Rails)
      require 'yarr/railtie'
      require 'yarr/migration'
      require 'yarr/migration/version'
      require 'yarr/migration/migrator'
    end
  end
end
