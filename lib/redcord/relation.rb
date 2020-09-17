# frozen_string_literal: true

# typed: strict

require 'active_support/core_ext/array'
require 'active_support/core_ext/module'

class Redcord::Relation
  extend T::Sig

  sig { returns(T.class_of(Redcord::Base)) }
  attr_reader :model

  sig { returns(T::Hash[Symbol, T.untyped]) }
  attr_reader :query_conditions

  sig { returns(T::Set[Symbol]) }
  attr_reader :select_attrs

  sig do
    params(
      model: T.class_of(Redcord::Base),
      query_conditions: T::Hash[Symbol, T.untyped],
      select_attrs: T::Set[Symbol],
    ).void
  end
  def initialize(
    model,
    query_conditions = {},
    select_attrs = Set.new
  )
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
    args: T.untyped,
    blk: T.nilable(T.proc.params(arg0: T.untyped).void),
  ).returns(T.any(Redcord::Relation, T::Array[T.untyped]))
  end
  def select(*args, &blk)
    Redcord::Base.trace(
     'redcord_relation_select',
     model_name: @model.name,
    ) do
      if block_given?
        return execute_query.select do |*item|
          blk.call(*item)
        end
      end

      select_attrs.merge(args)
      self
    end
  end

  sig { returns(Integer) }
  def count
    Redcord::Base.trace(
     'redcord_relation_count',
     model_name: @model.name,
    ) do
      redis.find_by_attr_count(model.model_key, query_conditions)
    end
  end

  delegate(
    :&,
    :[],
    :all?,
    :any?,
    :any?,
    :at,
    :collect!,
    :collect,
    :compact!,
    :compact,
    :each,
    :each_index,
    :empty?,
    :eql?,
    :exists?,
    :fetch,
    :fifth!,
    :fifth,
    :filter!,
    :filter,
    :first!,
    :first,
    :forty_two!,
    :forty_two,
    :fourth!,
    :fourth,
    :include?,
    :inspect,
    :last!,
    :last,
    :many?,
    :map!,
    :map,
    :none?,
    :one?,
    :reject!,
    :reject,
    :reverse!,
    :reverse,
    :reverse_each,
    :second!,
    :second,
    :second_to_last!,
    :second_to_last,
    :size,
    :sort!,
    :sort,
    :sort_by!,
    :take!,
    :take,
    :third!,
    :third,
    :third_to_last!,
    :third_to_last,
    :to_a,
    :to_ary,
    :to_h,
    :to_s,
    :zip,
    :|,
    to: :execute_query,
  )

  private

  sig { returns(T::Array[T.untyped]) }
  def execute_query
    Redcord::Base.trace(
     'redcord_relation_execute_query',
     model_name: @model.name,
    ) do
      if !select_attrs.empty?
        res_hash = redis.find_by_attr(
          model.model_key,
          query_conditions,
          select_attrs,
        )

        res_hash.map do |id, args|
          model.from_redis_hash(args).map do |k, v|
            [k.to_sym, TypeCoerce[model.get_attr_type(k.to_sym)].new.from(v)]
          end.to_h.merge(id: id)
        end
      else
        res_hash = redis.find_by_attr(
          model.model_key,
          query_conditions,
        )

        res_hash.map { |id, args| model.coerce_and_set_id(args, id) }
      end
    end
  end

  sig { returns(Redcord::PreparedRedis) }
  def redis
    model.redis
  end
end
