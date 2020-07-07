# typed: strict
require 'active_support/core_ext/module'

class Redcord::Relation
  extend T::Sig

  sig { returns(T.class_of(Redcord::Base)) }
  attr_reader :model
  
  sig { returns(T::Hash[Symbol, T.untyped]) }
  attr_reader :query_conditions

  sig { returns(T::Set[Symbol]) }
  attr_reader :select_attrs

  # TODO: Add sig for []
  delegate :[], to: :to_a

  sig do
    type_parameters(:U).params(
      blk: T.proc.params(arg0: Redcord::Base).returns(T.type_parameter(:U)),
    ).returns(T::Array[T.type_parameter(:U)])
  end
  def map(&blk)
    to_a.map(&blk)
  end

  sig do
    params(
      model: T.class_of(Redcord::Base),
      query_conditions: T::Hash[Symbol, T.untyped],
      select_attrs: T::Set[Symbol]
    ).void
  end
  def initialize(model, query_conditions={}, select_attrs=Set.new)
    @model = model
    @query_conditions = query_conditions
    @select_attrs = select_attrs
  end

  sig { params(args: T::Hash[Symbol, T.untyped]).returns(Redcord::Relation) }
  def where(args)
    encoded_args = args.map do |attr_key, attr_val|
      encoded_val = model.validate_and_encode_query(attr_key, attr_val)
      [attr_key, encoded_val]
    end
    query_conditions.merge!(encoded_args.to_h)
    self
  end

  sig do
    params(
    args: Symbol,
    blk: T.nilable(T.proc.params(arg0: T.untyped).void),
  ).returns(T.any(Redcord::Relation, T::Array[T.untyped]))
  end
  def select(*args, &blk)
    if block_given?
      return execute_query.select { |*item| blk.call(*item) }
    end
    select_attrs.merge(args)
    self
  end

  sig { returns(Integer) }
  def count
    redis.find_by_attr_count(model.model_key, query_conditions)
  end

  sig { returns(T::Array[T.untyped]) }
  def to_a
    execute_query
  end

  private
  sig { returns(T::Array[T.untyped]) }
  def execute_query
    if !select_attrs.empty?
      res_hash = redis.find_by_attr(model.model_key, query_conditions, select_attrs)
      return res_hash.map do |id, args|
        args = model.from_redis_hash(args)
        args = args.map { |k, v| [k.to_sym, TypeCoerce[model.get_attr_type(k.to_sym)].new.from(v)] }.to_h
        args.merge!(:id => id)
      end
    else
      res_hash = redis.find_by_attr(model.model_key, query_conditions)
      return res_hash.map { |id, args| model.coerce_and_set_id(args, id) }
    end
  end

  sig { returns(Redcord::PreparedRedis) }
  def redis
    model.redis
  end
end
