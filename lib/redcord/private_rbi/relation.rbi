# typed: true

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
  end

  sig { params(args: T::Hash[Symbol, T.untyped]).returns(Redcord::Relation) }
  def where(args)
  end

  sig do
    params(
    args: T.untyped,
    blk: T.nilable(T.proc.params(arg0: T.untyped).void),
  ).returns(T.any(Redcord::Relation, T::Array[T.untyped]))
  end
  def select(*args, &blk)
  end

  sig { returns(Integer) }
  def count
  end

  sig { params(index_name: T.nilable(Symbol)).returns(Redcord::Relation) }
  def with_index(index_name)
  end

  private

  sig { returns(T.nilable(String)) }
  def extract_hash_tag!
  end

  sig { returns(T::Array[T.untyped]) }
  def execute_query
  end

  sig { returns(Redcord::Redis) }
  def redis
  end

  sig { returns(T::Hash[Symbol, T.untyped]) }
  def query_conditions
  end

  sig { returns(T::Hash[Symbol, T.untyped]) }
  def extract_query_conditions!
  end
end
