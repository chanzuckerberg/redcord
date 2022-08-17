# frozen_string_literal: true
# typed: true
module Redcord::Base
  extend T::Sig
  extend T::Helpers

  sig { params(klass: T.class_of(T::Struct)).void }
  def self.included(klass)
  end

  sig { returns(T::Array[T.class_of(Redcord::Base)]) }
  def self.descendants
  end
end
