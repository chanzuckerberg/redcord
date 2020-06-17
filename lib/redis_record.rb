# typed: strict
module RedisRecord
end

require 'sorbet-runtime'

require 'redis_record/base'
require 'redis_record/migration'
require 'redis_record/migration/migrator'
require 'redis_record/migration/version'
require 'redis_record/railtie'
