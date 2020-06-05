# typed: strict
require 'sorbet-runtime'

module RedisRecord
  if defined?(Rails)
    require 'yarr/base'
  end
end
