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

  sig { returns(T.nilable(Symbol)) }
  attr_reader :index_name

  sig do
    params(
      model: T.class_of(Redcord::Base),
      query_conditions: T::Hash[Symbol, T.untyped],
      select_attrs: T::Set[Symbol],
      index_name: T.nilable(Symbol)
    ).void
  end
  def initialize(
    model,
    query_conditions = {},
    select_attrs = Set.new,
    index_name: nil
  )
    @model = model
    @query_conditions = query_conditions
    @select_attrs = select_attrs
    @index_name = index_name
  end

  sig { params(args: T::Hash[Symbol, T.untyped]).returns(Redcord::Relation) }
  def where(args)
    encoded_args = args.map do |attr_key, attr_val|
      encoded_val = model.validate_and_encode_query(attr_key, attr_val, index_name)
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
     model_name: model.name,
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
    redis.find_by_attr_count(
      model.model_key,
      query_conditions,
      index_attrs: model._script_arg_index_attrs,
      range_index_attrs: model._script_arg_range_index_attrs,
      custom_index_attrs: model._script_arg_custom_index_attrs[index_name],
      hash_tag: extract_hash_tag!,
      index_name: index_name
    )
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

  sig { returns(T.nilable(String)) }
  def extract_hash_tag!
    attr = model.class_variable_get(:@@shard_by_attribute)
    return nil if attr.nil?

    if !query_conditions.keys.include?(attr)
      raise "Queries must contain attribute '#{attr}' since model #{model.name} is sharded by this attribute"
    end

    condition = query_conditions[attr]
    if index_name and condition.first == condition.last
      condition = condition.first
    end
    case condition
    when Integer, String
      "{#{condition}}"
    else
      raise "Does not support query condition #{condition} on a Redis Cluster"
    end
  end

  sig { returns(T::Array[T.untyped]) }
  def execute_query
    Redcord::Base.trace(
     'redcord_relation_execute_query',
     model_name: model.name,
    ) do
      if !select_attrs.empty?
        res_hash = redis.find_by_attr(
          model.model_key,
          query_conditions,
          select_attrs: select_attrs,
          index_attrs: model._script_arg_index_attrs,
          range_index_attrs: model._script_arg_range_index_attrs,
          custom_index_attrs: model._script_arg_custom_index_attrs[index_name],
          hash_tag: extract_hash_tag!,
          index_name: index_name
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
          index_attrs: model._script_arg_index_attrs,
          range_index_attrs: model._script_arg_range_index_attrs,
          custom_index_attrs: model._script_arg_custom_index_attrs[index_name],
          hash_tag: extract_hash_tag!,
          index_name: index_name
        )

        res_hash.map { |id, args| model.coerce_and_set_id(args, id) }
      end
    end
  end

  sig { returns(Redcord::Redis) }
  def redis
    model.redis
  end
end
