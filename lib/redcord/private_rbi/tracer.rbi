# typed: true

module Redcord::Tracer
  extend T::Sig
  extend T::Helpers

  sig { params(klass: Module).void }
  def self.included(klass)
  end

  module ClassMethods
    include Kernel

    extend T::Sig

    @@tracer = T.let(nil, T.untyped)

    sig {
      params(
        span_name: String,
        model_name: String,
        tags: T::Array[String],
        blk: T.proc.returns(T.untyped),
      ).returns(T.untyped)
    }
    def trace(span_name, model_name:, tags: [], &blk)
    end

    sig { params(blk: T.proc.returns(T.untyped)).void }
    def tracer(&blk)
    end
  end
end
