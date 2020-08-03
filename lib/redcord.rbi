# typed: strong
module ModuleClassMethodsAsInstanceMethods
  # Sorbet does not understand the ClassMethods modules are actually defining
  # class methods. Hence this module redefines some top level class methods as
  # instance methods. Sigs are copied from
  # https://github.com/sorbet/sorbet/blob/f9380ec833047a834bbaca1eb3502ae96a0e4394/rbi/core/module.rbi
  include Kernel

  sig do
    params(
        arg0: T.any(Symbol, String),
    )
    .returns(T.untyped)
  end
  def class_variable_get(arg0); end

  sig do
    params(
        arg0: T.any(Symbol, String),
        arg1: BasicObject,
    )
    .returns(T.untyped)
  end
  def class_variable_set(arg0, arg1); end

  sig {returns(String)}
  def name(); end
end

module Redcord::RedisConnection::ClassMethods
  include ModuleClassMethodsAsInstanceMethods
end

module Redcord::RedisConnection::InstanceMethods
  include Kernel
end

module Redcord::Attribute::ClassMethods
  include Redcord::Serializer::ClassMethods
  # from inherenting T::Struct
  def prop(name, type, options={}); end
end

module Redcord::TTL::ClassMethods
  include Redcord::Serializer::ClassMethods
end

module Redcord::Actions::ClassMethods
  include Kernel
  include Redcord::RedisConnection::ClassMethods
  include Redcord::Serializer::ClassMethods
end

module Redcord::Actions::InstanceMethods
  include Kernel
  include Redcord::RedisConnection::InstanceMethods

  sig {returns(String)}
  def to_json; end

  sig {returns(T::Hash[String, T.untyped])}
  def serialize; end
end

module Redcord::Base
  include Redcord::Actions::InstanceMethods
  extend Redcord::Serializer::ClassMethods

  mixes_in_class_methods(Redcord::TTL::ClassMethods)
end

module Redcord::Serializer::ClassMethods
  include ModuleClassMethodsAsInstanceMethods

    # from inherenting T::Struct
    def from_hash(args); end
    def props; end
end
