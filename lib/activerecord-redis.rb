# typed: strict
require 'sorbet-runtime'

module RedisRecord
  if defined?(Rails)
    require 'redis_record/base'
  end
end
