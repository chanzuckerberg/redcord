# typed: true

module Redcord::Logger
  extend T::Sig
  extend T::Helpers

  sig { params(klass: Module).void }
  def self.included(klass)
  end

  module ClassMethods
    extend T::Sig

    @@logger = T.let(nil, T.untyped)

    sig { returns(T.untyped) }
    def logger
    end

    sig { params(logger: T.untyped).void }
    def logger=(logger)
    end
  end

  module LoggerMethods
    extend T::Sig

    sig do
      params(
        method: Symbol,
        args: T.untyped,
        blk: T.nilable(T.proc.returns(T.untyped))
      ).returns(T.untyped)
    end
    def self.method_missing(method, *args, &blk)
    end
  end

  sig { returns(T.untyped) }
  def self.proxy
  end
end

module Redcord::Base
  extend Redcord::Logger::ClassMethods
end
