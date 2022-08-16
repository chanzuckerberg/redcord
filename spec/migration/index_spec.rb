# frozen_string_literal: true


describe Redcord::Migration::Index do
  include Redcord::Migration::Index

  it 'drops an index' do
    klass = Class.new(T::Struct) do
      include Redcord::Base

      attribute :index, T.nilable(String), index: !cluster_mode?
      attribute :range_index, T.nilable(Integer), index: true

      shard_by_attribute :index if cluster_mode?

      def self.name
        'RedcordSpecModel'
      end
    end
    klass.establish_connection

    k = klass.create!(range_index: 1, index: '123')
    expect(klass.find_by(index: '123', range_index: 1).id).to eq k.id
    unless cluster_mode?
      expect(klass.find_by(index: '123').id).to eq k.id
    end

    klass = Class.new(T::Struct) do
      include Redcord::Base

      attribute :index, T.nilable(String)
      attribute :range_index, T.nilable(Integer)

      if cluster_mode?
        attribute :new_index, T.nilable(String)

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

  it "drops custom index" do
    klass = Class.new(T::Struct) do
      include Redcord::Base

      attribute :a, T.nilable(Integer)
      attribute :b, T.nilable(Integer)
      custom_index :first, [:a, :b]

      shard_by_attribute :a if cluster_mode?

      def self.name
        'RedcordSpecModelCustom'
      end
    end
    instance = klass.create!(a: 1, b: 1)
    expect(klass.where(a: 1, b: 1).with_index(:first).first.id).to eq instance.id
    index_key = "#{klass.model_key}:custom_index:first#{instance.hash_tag}"
    index_content_key = "#{klass.model_key}:custom_index:first_content#{instance.hash_tag}"
    index_string = klass.redis.hget(index_content_key, instance.id)
    expect(index_string).to be_kind_of(String)
    expect(klass.redis.zrangebylex(index_key, "[#{index_string}", "[#{index_string}").size).to eq(1)

    klass = Class.new(T::Struct) do
      include Redcord::Base
      attribute :a, T.nilable(Integer), index: !cluster_mode?
      attribute :b, T.nilable(Integer)

      shard_by_attribute :a if cluster_mode?

      def self.name
        'RedcordSpecModelCustom'
      end
    end

    expect {
      klass.where(a: 1, b: 1).with_index(:first).first.id
    }.to raise_error(Redcord::AttributeNotIndexed)

    remove_custom_index(klass, :first)
    expect(klass.redis.exists?(index_key)).to be(false)
    expect(klass.redis.exists?(index_content_key)).to be(false)
  end
end
