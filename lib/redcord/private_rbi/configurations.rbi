# typed: strict
module Redcord::Configurations
  sig { params(klass: Module).void }
  def self.included(klass)
  end

  module ClassMethods
    extend T::Sig

    @@configurations = T.let(
      Redcord::RedisConnection.merge_and_resolve_default({}),
      T::Hash[String, T.untyped]
    )

    sig { returns(T::Hash[String, T.untyped]) }
    def configurations
    end

    sig { params(config: T::Hash[String, T.untyped]).void }
    def configurations=(config)
    end
  end
end

module Redcord::Base
  extend Redcord::Configurations::ClassMethods
end
