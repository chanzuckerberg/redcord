# frozen_string_literal: true

# typed: strict

require 'active_support'
require 'active_support/core_ext/array'
require 'active_support/core_ext/module'

module Redcord
  class InvalidQuery < StandardError; end
end

class Redcord::Relation
  extend T::Sig

  sig { returns(T.class_of(Redcord::Base)) }
  attr_reader :model

  sig { returns(T::Set[Symbol]) }
  attr_reader :select_attrs

  sig { returns(T.nilable(Symbol)) }
  attr_reader :custom_index_name

  sig { returns(T::Hash[Symbol, T.untyped]) }
  attr_reader :regular_index_query_conditions

  sig { returns(T::Hash[Symbol, T.untyped]) }
  attr_reader :custom_index_query_conditions

  sig do
    params(
      model: T.class_of(Redcord::Base),
      regular_index_query_conditions: T::Hash[Symbol, T.untyped],
      custom_index_query_conditions: T::Hash[Symbol, T.untyped],
      select_attrs: T::Set[Symbol],
      custom_index_name: T.nilable(Symbol)
    ).void
  end
  def initialize(
    model,
    regular_index_query_conditions = {},
    custom_index_query_conditions = {},
    select_attrs = Set.new,
    custom_index_name: nil
  )
    @model = model
    @regular_index_query_conditions = regular_index_query_conditions
    @custom_index_query_conditions = custom_index_query_conditions
    @select_attrs = select_attrs
    @custom_index_name = custom_index_name
  end

  sig { params(args: T::Hash[Symbol, T.untyped]).returns(Redcord::Relation) }
  def where(args)
    encoded_args = args.map do |attr_key, attr_val|
      encoded_val = model.validate_types_and_encode_query(attr_key, attr_val)
      [attr_key, encoded_val]
    end

    regular_index_query_conditions.merge!(encoded_args.to_h)
    if custom_index_name
      with_index(custom_index_name)
    end
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
    Redcord::Base.trace(
     'redcord_relation_count',
     model_name: model.name,
    ) do
      model.validate_index_attributes(query_conditions.keys, custom_index_name: custom_index_name)
      redis.find_by_attr_count(
        model.model_key,
        extract_query_conditions!,
        index_attrs: model._script_arg_index_attrs,
        range_index_attrs: model._script_arg_range_index_attrs,
        custom_index_attrs: model._script_arg_custom_index_attrs[custom_index_name],
        hash_tag: extract_hash_tag!,
        custom_index_name: custom_index_name
      )
    end
  end

  sig { params(index_name: T.nilable(Symbol)).returns(Redcord::Relation) }
  def with_index(index_name)
    @custom_index_name = index_name
    adjusted_query_conditions = model.validate_and_adjust_custom_index_query_conditions(regular_index_query_conditions)
    custom_index_query_conditions.merge!(adjusted_query_conditions)
    self
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
    attr = model.shard_by_attribute
    return nil if attr.nil?

    if !query_conditions.keys.include?(attr)
      raise(
        Redcord::InvalidQuery,
        "Queries must contain attribute '#{attr}' since model #{model.name} is sharded by this attribute"
      )
    end

    # Query conditions on custom index are always in form of range, even when query is by value condition is [value_x, value_x]
    # When in fact query is by value, range is trasformed to a single value to pass the validation.
    condition = query_conditions[attr]
    if custom_index_name and condition.first == condition.last
      condition = condition.first
    end
    case condition
    when Integer, String
      "{#{condition}}"
    else
      raise(
        Redcord::InvalidQuery,
        "Does not support query condition #{condition} on a Redis Cluster",
      )
    end
  end

  sig { returns(T::Array[T.untyped]) }
  def execute_query
    Redcord::Base.trace(
     'redcord_relation_execute_query',
     model_name: model.name,
    ) do
      model.validate_index_attributes(query_conditions.keys, custom_index_name: custom_index_name)
      if !select_attrs.empty?
        res_hash = redis.find_by_attr(
          model.model_key,
          extract_query_conditions!,
          select_attrs: select_attrs,
          index_attrs: model._script_arg_index_attrs,
          range_index_attrs: model._script_arg_range_index_attrs,
          custom_index_attrs: model._script_arg_custom_index_attrs[custom_index_name],
          hash_tag: extract_hash_tag!,
          custom_index_name: custom_index_name
        )

        res_hash.map do |id, args|
          model.from_redis_hash(args).map do |k, v|
            [k.to_sym, TypeCoerce[model.get_attr_type(k.to_sym)].new.from(v)]
          end.to_h.merge(id: id)
        end
      else
        res_hash = redis.find_by_attr(
          model.model_key,
          extract_query_conditions!,
          index_attrs: model._script_arg_index_attrs,
          range_index_attrs: model._script_arg_range_index_attrs,
          custom_index_attrs: model._script_arg_custom_index_attrs[custom_index_name],
          hash_tag: extract_hash_tag!,
          custom_index_name: custom_index_name
        )

        res_hash.map { |id, args| model.coerce_and_set_id(args, id) }
      end
    end
  end

  sig { returns(Redcord::RedisConnection::RedcordClientType) }
  def redis
    model.redis
  end

  sig { returns(T::Hash[Symbol, T.untyped]) }
  def query_conditions
    custom_index_name ? custom_index_query_conditions : regular_index_query_conditions
  end

  sig { returns(T::Hash[Symbol, T.untyped]) }
  def extract_query_conditions!
    attr = model.shard_by_attribute
    return query_conditions if attr.nil?

    cond = query_conditions.reject { |key| key == attr }
    raise Redcord::InvalidQuery, "Cannot query only by shard_by_attribute: #{attr}" if cond.empty?

    cond
  end
end
