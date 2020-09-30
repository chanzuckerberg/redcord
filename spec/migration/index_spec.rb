# frozen_string_literal: true

# typed: false

describe Redcord::Migration::Index do
  include Redcord::Migration::Index

  it 'drops an index' do
    klass = Class.new(T::Struct) do
      include Redcord::Base

      attribute :regular_index, T.nilable(String), index: true
      attribute :range_index, T.nilable(Integer), index: true

      def self.name
        'RedcordSpecModel'
      end
    end
    klass.establish_connection

    k = klass.create!(range_index: 1, regular_index: '123')
    expect(klass.find_by(range_index: 1).id).to eq k.id
    expect(klass.find_by(regular_index: '123').id).to eq k.id

    klass = Class.new(T::Struct) do
      include Redcord::Base

      attribute :regular_index, T.nilable(String)
      attribute :range_index, T.nilable(Integer)

      def self.name
        'RedcordSpecModel'
      end
    end
    klass.establish_connection

    # Still using the previous index before running migrations
    klass.create!(range_index: 1, regular_index: '321')
    expect(klass.redis.exists?("#{klass.model_key}:regular_index:321")).to be true
    expect(klass.redis.exists?("#{klass.model_key}:range_index")).to be true

    expect {
      klass.find_by(regular_index: '123').id
    }.to raise_error(Redcord::AttributeNotIndexed)

    expect {
      klass.find_by(range_index: 1).id
    }.to raise_error(Redcord::AttributeNotIndexed)

    remove_index(klass, :regular_index)
    remove_index(klass, :range_index)
    klass.create!(range_index: 2, regular_index: '456')
    expect(klass.redis.keys("#{klass.model_key}:regularindex:*")).to eq([])
    expect(klass.redis.keys("#{klass.model_key}:range_index")).to eq([])
    expect(klass.redis.keys("#{klass.model_key}:range_index:*")).to eq([])
  end
end
