# frozen_string_literal: true

# typed: strict

module Redcord::Tracer
  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    include Kernel

    extend T::Sig

    @@tracer = T.let(nil, T.untyped)

    def trace(span_name, model_name:, tags: [], &blk)
      return blk.call if @@tracer.nil?

      @@tracer.call.trace(
        span_name,
        resource: model_name,
        service: 'redcord',
        tags: tags,
        &blk
      )
    end

    def tracer(&blk)
      @@tracer = blk
    end
  end
end
