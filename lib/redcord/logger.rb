# typed: true

require 'rails'

module Redcord::Logger
  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    @@logger = nil

    def logger
      @@logger
    end

    def logger=(logger)
      @@logger = logger
    end
  end

  module LoggerMethods
    #
    # Forward all the logger methods call to a module -- almost all logger
    # methods are missing and handled by method_missing. We use this trick to
    # dynamically swap loggers without reconfiguring the Redis clients.
    #
    def self.method_missing(method, *args, &blk)
      logger = Redcord::Base.logger
      return if logger.nil?
      logger.send(method, *args)
    end
  end

  # If we set the logger to nil, but we're not rebuilding the connection(s) at
  # all.
  # Example:
  #
  #   2.5.5 :001 > Redcord::Base.redis.ping
  #   [Redis] command=PING args=
  #   [Redis] call_time=0.80 ms
  #    => "PONG"
  #   2.5.5 :002 > Redcord::Base.logger = nil
  #    => nil
  #   2.5.5 :003 > Redcord::Base.redis.ping # show no logs
  #    => "PONG"
  #
  def self.proxy
    Redcord::Logger::LoggerMethods
  end
end
