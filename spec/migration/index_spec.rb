# frozen_string_literal: true

# typed: false

describe Redcord::Migration::Index do
  include Redcord::Migration::Index

  it 'drops an index' do
    klass = Class.new(T::Struct) do
      include Redcord::Base

      attribute :index, T.nilable(String), index: true
      attribute :range_index, T.nilable(Integer), index: true

      if ENV['REDCORD_SPEC_USE_CLUSTER'] == 'true'
        shard_by_attribute :index
      end

      def self.name
        'RedcordSpecModel'
      end
    end
    klass.establish_connection

    k = klass.create!(range_index: 1, index: '123')
    expect(klass.find_by(index: '123', range_index: 1).id).to eq k.id
    expect(klass.find_by(index: '123').id).to eq k.id

    klass = Class.new(T::Struct) do
      include Redcord::Base

      attribute :index, T.nilable(String)
      attribute :range_index, T.nilable(Integer)

      if ENV['REDCORD_SPEC_USE_CLUSTER'] == 'true'
        attribute :new_index, T.nilable(String), index: true

        shard_by_attribute :new_index
      end

      def self.name
        'RedcordSpecModel'
      end
    end
    klass.establish_connection

    expect {
      klass.find_by(index: '123').id
    }.to raise_error(Redcord::AttributeNotIndexed)

    expect {
      klass.find_by(range_index: 1).id
    }.to raise_error(Redcord::AttributeNotIndexed)

    remove_index(klass, :index)
    remove_index(klass, :range_index)
    klass.create!(range_index: 2, index: '456')
    expect(klass.redis.keys("#{klass.model_key}:index:*")).to eq([])
    expect(klass.redis.keys("#{klass.model_key}:range_index")).to eq([])
    expect(klass.redis.keys("#{klass.model_key}:range_index:*")).to eq([])
  end
end
