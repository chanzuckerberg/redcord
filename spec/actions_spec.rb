# frozen_string_literal: true

# typed: false

describe Redcord::Actions do
  let!(:klass) do
    Class.new(T::Struct) do
      include Redcord::Base

      attribute :value, T.nilable(Integer)
      attribute :time_value, T.nilable(Time)
      attribute :indexed_value, T.nilable(Integer), index: true
      custom_index :first, [:value, :time_value]
      custom_index :second, [:time_value]

      if ENV['REDCORD_SPEC_USE_CLUSTER'] == 'true'
        shard_by_attribute :indexed_value
      end

      def self.name
        'RedcordSpecModel'
      end
    end
  end

  let!(:migrator) do
    Class.new do
      extend Redcord::Migration::TTL
    end
  end

  context 'create' do
    it '#create!' do
      instance = klass.create!(value: 3)
      another_instance = klass.find(instance.id)
      expect(instance.value).to eq another_instance.value
      expect(klass.count).to eq 1
    end

    it 'validates types' do
      # TODO: this should raise an error
      klass.create!(value: '1')
    end

    it 'errors when uuids collide' do
      allow(SecureRandom).to receive(:uuid).and_return('fixed')
      klass.create!(value: '1')

      expect {
        klass.create!(value: '1')
      }.to raise_error(Redis::CommandError)
    end
  end

  context 'update' do
    it '#update!' do
      instance = klass.create!(value: 3)
      expect(instance.value).to eq 3

      expect {
        instance.value = '4'
      }.to raise_error(TypeError)

      expect {
        instance.update!(value: '4')
      }.to raise_error(TypeError)


      if ENV['REDCORD_SPEC_USE_CLUSTER'] == 'true'
        # Cannot update shard_by attribute
        expect {
          instance.update!(indexed_value: 4)
        }.to raise_error(RuntimeError)
      end

      instance.update!(value: 4)
      expect(instance.value).to eq 4

      another_instance = klass.find(instance.id)
      expect(instance.value).to eq another_instance.value

      instance = klass.new(value: 3)
      instance.update!(value: 4)
      another_instance = klass.find(instance.id)
      expect(instance.value).to eq another_instance.value
    end

    it '#save!' do
      instance = klass.new(value: 3)
      expect(instance.value).to eq 3
      expect(instance.updated_at).to be_nil
      expect(instance.id).to be_nil
      expect {
        # instance_key is not available when id is nil
        instance.instance_key
      }.to raise_error(TypeError)
      expect(klass.count).to eq 0
      instance.save!
      expect(klass.count).to eq 1

      expect(instance.created_at).not_to be_nil
      expect(instance.updated_at).not_to be_nil

      another_instance = klass.find(instance.id)
      expect(instance.value).to eq another_instance.value
    end

    it '#save' do
      instance = klass.create!(value: 3, indexed_value: 1)
      instance.destroy # e.g. the record is destroyed by another process
      expect(instance.save).to be false
    end

    it 'doesn\'t update redis until save!/update! is called' do
      instance = klass.create!(value: 3)
      instance.value = 4
      expect(klass.count).to eq 1

      another_instance = klass.find(instance.id)
      expect(another_instance.value).to eq 3

      instance.save!
      another_instance = klass.find(instance.id)
      expect(another_instance.value).to eq instance.value
      expect(klass.count).to eq 1
    end

    it 'resets ttl' do
      instance = klass.create!(value: 3)

      klass.ttl(2.days)
      expect(klass.redis.ttl(instance.instance_key)).to eq(-1)

      instance.save!
      expect(klass.redis.ttl(instance.instance_key) > 0).to be true

      klass.ttl(nil)
      instance.update!(value: 4)
      expect(klass.redis.ttl(instance.instance_key)).to eq(-1)
    end

    it 'resets ttl actively' do
      instance = klass.create!(value: 3)

      klass.ttl(2.days)
      expect(klass.redis.ttl(instance.instance_key)).to eq(-1)

      migrator.change_ttl_active(klass)
      expect(klass.redis.ttl(instance.instance_key) > 0).to be true

      instance = klass.create!(value: 3)
      expect(klass.redis.ttl(instance.instance_key) > 0).to be true
    end
  end

  context 'read' do
    it '#find' do
      non_existing_id = 1

      expect {
        # CLUSTERDOWN is thrown occasionally on CI when a key does not exist.
        # The cause of this behavior is currently unknown but likely due to the
        # CI envrionment.
        begin
          klass.find(non_existing_id)
        rescue Redis::CommandError => e
          if e.message != 'CLUSTERDOWN The cluster is down'
            raise e
          end

          sleep(0.5)
          retry
        end
      }.to raise_error(Redcord::RecordNotFound)

      instance = klass.create!(value: 1)

      another_instance = klass.find(instance.id)

      expect(another_instance.id).to eq instance.id
      expect(another_instance.value).to eq instance.value
    end

    it '#where' do
      instance = klass.create!(indexed_value: 1)
      another_instance = klass.where(
        indexed_value: instance.indexed_value,
      ).to_a.first

      expect(another_instance.id).to eq instance.id
      expect(another_instance.indexed_value).to eq instance.indexed_value
    end

    it '#find_by' do
      instance = klass.create!(indexed_value: 1)
      another_instance = klass.find_by(indexed_value: instance.indexed_value)

      expect(another_instance.id).to eq instance.id
      expect(another_instance.indexed_value).to eq instance.indexed_value

      expect(klass.find_by(indexed_value: 0)).to be_nil
    end
  end

  context 'delete' do
    it '#destroy' do
      expect(klass.count).to eq 0
      instance = klass.create!(value: 1)
      expect(klass.count).to eq 1

      another_instance = klass.find(instance.id)
      expect(another_instance.id).to eq instance.id
      expect(another_instance.value).to eq instance.value
      expect(another_instance.created_at).to eq instance.created_at
      expect(another_instance.updated_at).to eq instance.updated_at

      instance.destroy

      expect(klass.count).to eq 0

      expect {
        klass.find(instance.id)
      }.to raise_error(Redcord::RecordNotFound)
    end

    it 'does not save/update a destroyed record' do
      instance = klass.create!(value: 1)
      expect(klass.count).to eq 1
      instance.destroy
      expect(klass.count).to eq 0

      expect {
        instance.save!
      }.to raise_error(Redis::CommandError)
      expect(klass.count).to eq 0

      expect {
        instance.update!(value: 2)
      }.to raise_error(Redis::CommandError)
      expect(klass.count).to eq 0
    end

    it 'deletes a non-existing record' do
      instance = klass.new(value: 1)
      expect(instance.id).to be_nil
      expect {
        instance.destroy
      }.to_not raise_error
      expect(klass.count).to eq 0
    end
  end

  context 'custom indexes: ' do
    let!(:time_now) { Time.zone.now}
    let!(:instance) { klass.create!(value: 1, time_value: time_now) }
    let!(:instance_2) { klass.create!(value: 2, time_value: nil) }

    it 'returns instance by int attribute query' do
      expect(klass.where(value: 1, index: :first).to_a.first.id).to eq(instance.id)
    end

    it 'returns count by int attribute query' do
      expect(klass.where(value: 1, index: :first).count).to eq(1)
      expect(klass.where(value: 3, index: :first).count).to eq(0)
    end

    it 'returns instance by time attribute range query' do
      interval = Redcord::RangeInterval.new(min: time_now - 10.seconds)
      expect(klass.where(time_value: interval, index: :second).to_a.first.id).to eq(instance.id)
    end

    it 'returns instance by attribute is nil query' do
      expect(klass.where(time_value: nil, index: :second).to_a.first.id).to eq(instance_2.id)
    end

    it 'returns instance by int and time attributes range query' do
      interval = Redcord::RangeInterval.new(min: time_now - 10.seconds)
      expect(klass.where(value: 1, time_value: interval, index: :first).to_a.first.id).to eq(instance.id)
    end

    it 'returns instance by int and time attributes is nil query' do
      expect(klass.where(value: 2, time_value: nil, index: :first).to_a.first.id).to eq(instance_2.id)
    end

    it 'returns selected attributes' do
      expect(klass.where(value: 1, index: :first).select(:time_value).first[:time_value].to_i).to eq(instance.time_value.to_i)
    end

    it 'raises error when attributes are in incorrect order' do
      expect {
        klass.where(time_value: nil, index: :first).to_a
      }.to raise_error(Redis::CommandError)
    end

    it 'raises error when range query conditions are used not on trhe last attribute in a query' do
      interval = Redcord::RangeInterval.new(min: 0)
      expect {
        klass.where(value: interval, time_value: nil, index: :first).to_a
      }.to raise_error(Redis::CommandError)
    end

    it 'raises error when attributes are not part of specified index' do
      expect {
        klass.where(indexed_value: nil, index: :first).to_a
      }.to raise_error(Redcord::AttributeNotIndexed)
    end
  end
end
