# frozen_string_literal: true

# typed: strict

module Redcord::Tracer
  extend T::Sig
  extend T::Helpers

  sig { params(klass: Module).void }
  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    include Kernel

    extend T::Sig

    @@tracer = T.let(nil, T.untyped)

    sig {
      params(
        span_name: String,
        model_name: String,
        tags: T::Hash[String, String],
        blk: T.proc.returns(T.untyped),
      ).returns(T.untyped)
    }
    def trace(span_name, model_name:, tags: {}, &blk)
      return blk.call if @@tracer.nil?

      @@tracer.call.trace(
        span_name,
        resource: model_name,
        service: 'redcord',
        tags: tags,
        &blk
      )
    end

    sig { params(blk: T.proc.returns(T.untyped)).void }
    def tracer(&blk)
      @@tracer = blk
    end
  end

  mixes_in_class_methods(ClassMethods)
end
