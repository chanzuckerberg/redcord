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

module RedisRecord::RedisConnection::ClassMethods
  include ModuleClassMethodsAsInstanceMethods
end

module RedisRecord::RedisConnection::InstanceMethods
  include Kernel
end

module RedisRecord::Attribute::ClassMethods
  include RedisRecord::Serializer::ClassMethods
  # from inherenting T::Struct
  def prop(name, type, options={}); end
end

module RedisRecord::TTL::ClassMethods
  include RedisRecord::Serializer::ClassMethods
end

module RedisRecord::ServerScripts
  include Kernel

  sig do
    params(
      sha: String,
      keys: T::Array[T.untyped],
      argv: T::Array[T.untyped],
    ).returns(T.untyped)
  end
  def evalsha(sha, keys: [], argv:[]); end

  sig { returns(T::Hash[Symbol, String]) }
  def redis_record_server_script_shas; end
end

module RedisRecord::Actions::ClassMethods
  include Kernel
  include RedisRecord::RedisConnection::ClassMethods
  include RedisRecord::Serializer::ClassMethods
end

module RedisRecord::Actions::InstanceMethods
  include Kernel
  include RedisRecord::RedisConnection::InstanceMethods

  sig {returns(String)}
  def to_json; end

  sig {returns(T::Hash[String, T.untyped])}
  def serialize; end
end

module RedisRecord::Base
  include RedisRecord::Actions::InstanceMethods
  extend RedisRecord::Serializer::ClassMethods

  mixes_in_class_methods(RedisRecord::TTL::ClassMethods)
end

module RedisRecord::Serializer::ClassMethods
  include ModuleClassMethodsAsInstanceMethods

    # from inherenting T::Struct
    def from_hash(args); end
    def props; end
end
