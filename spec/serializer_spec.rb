# frozen_string_literal: true

# typed: false

describe Redcord::Serializer do
  let(:klass) do
    Class.new(T::Struct) do
      include Redcord::Base

      attribute :a, Integer, index: true
      attribute :b, String, index: true
      attribute :c, Integer
      attribute :d, T.nilable(Time), index: true
      attribute :float, T.nilable(Float), index: true
      attribute :boolean, T.nilable(T::Boolean), index: true

      if ENV['REDCORD_SPEC_USE_CLUSTER'] == 'true'
        shard_by_attribute :a
      end

      def self.name
        'RedcordSpecModel'
      end
    end
  end

  it 'works with time types' do
    now = Time.zone.now
    allow(Time.zone).to receive(:now).and_return(now)
    allow(Time).to receive(:now).and_return(now)

    instance = klass.create!(a: 3, b: '3', c: 3)
    another_instance = klass.find_by(a: 3)

    expect(instance.d).to be_nil
    expect(instance.created_at).to eq(now)
    expect(instance.updated_at).to eq(now)
    expect(instance.created_at).to eq(another_instance.created_at)
    expect(instance.updated_at).to eq(another_instance.updated_at)

    now = Time.zone.at(-1000)
    allow(Time.zone).to receive(:now).and_return(now)
    allow(Time).to receive(:now).and_return(now)

    instance = klass.create!(a: 4, b: '4', c: 4)
    another_instance = klass.find_by(a: 4)
    expect(instance.created_at).to eq(now)
    expect(instance.updated_at).to eq(now)
    expect(instance.created_at).to eq(another_instance.created_at)
    expect(instance.updated_at).to eq(another_instance.updated_at)
  end

  it 'works with boolean types' do
    instance = klass.create!(a: 3, b: '3', c: 3, boolean: true)
    another_instance = klass.find_by(a: 3, boolean: true)

    expect(instance.id).to eq(another_instance.id)
    expect(klass.find_by(a: 3, boolean: false)).to be_nil
    expect(klass.find_by(a: 3, boolean: nil)).to be_nil
  end

  it 'works with float types' do
    klass.create!(a: 3, b: '3', c: 3, float: 1.0)
    klass.create!(a: 3, b: '3', c: 3, float: 2.0)
    klass.create!(a: 3, b: '3', c: 3, float: 3.0)

    expect(klass.find_by(a: 3, float: 1.0)).to_not be_nil
    expect(klass.find_by(
      a: 3,
      float: Redcord::RangeInterval.new(min: 0.0)),
    ).to_not be_nil
    expect(klass.find_by(
      a: 3,
      float: Redcord::RangeInterval.new(min: 4.0)),
    ).to be_nil

    # round trip
    klass.create!(a: 3, b: '3', c: 3, float: 1.0 / 3.0)
    expect(klass.find_by(
      a: 3,
      float: 1.0 / 3.0,
    )).to_not be_nil
  end

  context 'when query is invalid' do
    it 'throws an error when given an attribute of the wrong type' do
      expect {
        klass.where(a: '3')
      }.to raise_error(Redcord::WrongAttributeType)

      expect {
        klass.where(a: Redcord::RangeInterval.new(min: 1, max: 5.0))
      }.to raise_error(Redcord::WrongAttributeType)
    end

    it 'throws an error when given an attribute that is not indexed' do
      expect {
        klass.where(c: 3)
      }.to raise_error(Redcord::AttributeNotIndexed)
    end
  end

  it 'works with exclusive range intervals' do
    first = klass.create!(a: 3, b: '3', c: 3)
    second = klass.create!(a: 2, b: '2', c: 3)

    if ENV['REDCORD_SPEC_USE_CLUSTER'] == 'true'
      # Since we shard by a, we must use equality
      expect {
        klass.where(
          a: Redcord::RangeInterval.new(max: 3, max_exclusive: true),
        ).count
      }.to raise_error(Redcord::WrongAttributeType)
    else
      queried_instances = klass.where(
        a: Redcord::RangeInterval.new(max: 3, max_exclusive: true),
      )
      expect(queried_instances.size).to eq 1
      expect(queried_instances.first.id).to eq(second.id)

      queried_instances = klass.where(
        a: Redcord::RangeInterval.new(min: 2, min_exclusive: true),
      )
      expect(queried_instances.size).to eq 1
      expect(queried_instances.first.id).to eq(first.id)
    end
  end

  it 'allows combining range and equality conditions in queries' do
    first = klass.create!(a: 3, b: '3', c: 3, float: 3.0)

    queried_instances = klass.where(
      a: 3,
      b: '3',
      float: Redcord::RangeInterval.new(max: 5.0),
    )
    expect(queried_instances.size).to eq 1
    expect(queried_instances.first.id).to eq first.id

    queried_instances = klass.where(
      a: 3,
      b: '2',
      float: Redcord::RangeInterval.new(max: 3.0),
    )
    expect(queried_instances.size).to eq 0

    queried_instances = klass.where(
      a: 3,
      b: '4',
      float: Redcord::RangeInterval.new(min: 5.0),
    )
    expect(queried_instances.size).to eq 0
  end

  it 'allows time types to be range index attributes' do
    first = klass.create!(a: 3, b: '3', c: 3, d: Time.zone.now - 1.hour)
    second = klass.create!(a: 3, b: '3', c: 3, d: Time.zone.now)

    queried_instances = klass.where(
      a: 3,
      d: Redcord::RangeInterval.new(max: Time.zone.now + 1.day),
    )
    expect(queried_instances.size).to eq 2
    expect(queried_instances.first.id).to eq(first.id).or eq(second.id)
    expect(queried_instances.second.id).to eq(first.id).or eq(second.id)
  end

  it 'allows nil values for range index attributes' do
    first = klass.create!(a: 3, b: '3', c: 3, d: nil)

    queried_instances = klass.where(a: 3, d: nil)
    expect(queried_instances.size).to eq 1
    expect(queried_instances.first.id).to eq first.id
  end

  it 'allows queries for multiple index attributes' do
    first = klass.create!(a: 3, b: '3', c: 3)
    second = klass.create!(a: 3, b: '4', c: 3)

    # query with one attribute should return both values
    queried_instances = klass.where(a: 3)
    expect(queried_instances.size).to eq 2
    expect(queried_instances.map(&:id).sort).to eq([first.id, second.id].sort)

    queried_instances = klass.where(a: 3, b: '3')
    expect(queried_instances.size).to eq 1
    expect(queried_instances.first.id).to eq first.id
  end
end
