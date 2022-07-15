# frozen_string_literal: true

# typed: ignore

describe Redcord::Relation do
  let(:klass) do
    Class.new(T::Struct) do
      include Redcord::Base

      attribute :a, Integer, index: !cluster_mode?
      attribute :b, String, index: true
      attribute :c, Integer
      attribute :d, T.nilable(Time), index: true

      if cluster_mode?
        shard_by_attribute :a
      end

      def self.name
        'RedcordSpecModel'
      end
    end
  end

  it 'maintains index id sets after an update operation' do
    instance = klass.create!(a: 3, b: '3', c: 4)

    instance.update!(b: '4')

    # query for previous value of a should be empty, and new value should be
    # updated.
    expect(klass.where(a: 3, b: '3').count).to eq 0

    queried_instances = klass.where(a: 3, b: '4')
    expect(queried_instances.size).to eq 1
    expect(queried_instances.first.id).to eq instance.id

    # other index attributes not changed should be untouched
    unless cluster_mode?
      queried_instances = klass.where(a: 3)
      expect(queried_instances.count).to eq 1
      expect(queried_instances.first.id).to eq instance.id
    end

    queried_instances = klass.where(a: 3, d: nil)
    expect(queried_instances.count).to eq 1
    expect(queried_instances.first.id).to eq instance.id
  end

  it 'maintains index id sets after delete operation' do
    instance = klass.create!(a: 3, b: '3', c: 3)
    instance.destroy

    queried_instances = klass.where(a: 3, b: '3')
    expect(queried_instances.size).to eq 0
  end

  it 'supports chaining select index query method' do
    first = klass.create!(a: 3, b: '3', c: 3)
    klass.create!(a: 3, b: '4', c: 3)

    queried_instances = klass.where(a: 3, b: '3').select(:c)
    expect(queried_instances.size).to eq 1
    expect(queried_instances[0][:id]).to eq(first.id)
    expect(queried_instances[0][:a]).to be_nil
    expect(queried_instances[0][:b]).to be_nil
    expect(queried_instances[0][:c]).to eq(3)
  end

  it 'does not chain the select method if a block is given' do
    first = klass.create!(a: 3, b: '3', c: 3)
    klass.create!(a: 3, b: '4', c: 3)

    queried_instances = klass.where(a: 3, d: nil).select { |r| r.b == '3' }
    expect(queried_instances.size).to eq 1
    expect(queried_instances[0].id).to eq(first.id)
  end

  it 'supports chaining count index query method' do
    klass.create!(a: 3, b: '3', c: 3)
    klass.create!(a: 3, b: '4', c: 3)

    count = klass.where(a: 3, d: nil).count
    expect(count).to eq 2

    expect(klass.where(a: 0, d: nil).count).to eq 0
  end

  if cluster_mode?
    it 'does not allow queries without shard_by attribute' do
      # Cannot query without shard_by attribute
      expect {
        klass.where(b: '3').count
      }.to raise_error(Redcord::InvalidQuery)
    end
  end
end
