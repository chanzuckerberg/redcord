# typed: strict
module RedisRecord::Logger
  sig { params(klass: Module).void }
  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    @@logger = T.let(Rails.logger, T.untyped)

    sig { returns(T.untyped) }
    def logger
      @@logger
    end

    sig { params(logger: T.untyped).void }
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
    sig do
      params(
        method: Symbol,
        args: T.untyped,
        blk: T.nilable(T.proc.returns(T.untyped))
      ).returns(T.untyped)
    end
    def self.method_missing(method, *args, &blk)
      logger = RedisRecord::Base.logger
      return if logger.nil?
      logger.send(method, *args)
    end
  end

  # If we set the logger to nil, but we're not rebuilding the connection(s) at
  # all.
  # Example:
  #
  #   2.5.5 :001 > RedisRecord::Base.redis.ping
  #   [Redis] command=PING args=
  #   [Redis] call_time=0.80 ms
  #    => "PONG"
  #   2.5.5 :002 > RedisRecord::Base.logger = nil
  #    => nil
  #   2.5.5 :003 > RedisRecord::Base.redis.ping # show no logs
  #    => "PONG"
  #
  sig { returns(T.untyped) }
  def self.proxy
    RedisRecord::Logger::LoggerMethods
  end

  mixes_in_class_methods(ClassMethods)
end
