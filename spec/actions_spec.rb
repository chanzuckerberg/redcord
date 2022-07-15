# frozen_string_literal: true

# typed: ignore

describe Redcord::Actions do
  let!(:klass) do
    Class.new(T::Struct) do
      include Redcord::Base

      attribute :value, T.nilable(Integer)
      attribute :time_value, T.nilable(Time)
      attribute :indexed_value, T.nilable(Integer), index: !cluster_mode?
      attribute :other_value, T.nilable(Integer), index: true

      shard_by_attribute :indexed_value if cluster_mode?

      def self.name
        'RedcordSpecModel'
      end
    end
  end

  let!(:klass_with_boolean) do
    Class.new(T::Struct) do
      include Redcord::Base

      attribute :value, T::Boolean, index: !cluster_mode?

      shard_by_attribute :value if cluster_mode?

      def self.name
        'RedcordSpecModelOther'
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
      begin
        instance = klass.create!(value: 3)
      rescue Redis::CommandError => e
        if e.message != 'CLUSTERDOWN The cluster is down'
          raise e
        end
        sleep(0.5)
        retry
      end
      another_instance = klass.find(instance.id)
      expect(instance.value).to eq another_instance.value
      expect(klass.count).to eq 1
    end

    it 'creates an instance with boolean attribute' do
      begin
        instance = klass_with_boolean.create!(value: true)
      rescue Redis::CommandError => e
        if e.message != 'CLUSTERDOWN The cluster is down'
          raise e
        end
        sleep(0.5)
        retry
      end
      another_instance = klass_with_boolean.find(instance.id)
      expect(instance.value).to eq another_instance.value
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


      if cluster_mode?
        # Cannot update shard_by attribute
        expect {
          instance.update!(indexed_value: 4)
        }.to raise_error(Redcord::InvalidAction)
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

    it '#update' do
      instance = klass.create!(value: 3, indexed_value: 1)
      instance.destroy # e.g. the record is destroyed by another process
      expect(instance.update(value: 4)).to be false
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

    it 'uses save to create an instance with boolean attribute' do
      begin
        instance = klass_with_boolean.new(value: false)
      rescue Redis::CommandError => e
        if e.message != 'CLUSTERDOWN The cluster is down'
          raise e
        end
        sleep(0.5)
        retry
      end
      instance.save!
      another_instance = klass_with_boolean.find(instance.id)
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
      begin
        instance = klass.create!(value: 3)
      rescue Redis::CommandError => e
        if e.message != 'CLUSTERDOWN The cluster is down'
          raise e
        end
        sleep(0.5)
        retry
      end

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

      if cluster_mode?
        expect {
          klass.where(
            indexed_value: instance.indexed_value,
          ).to_a
        }.to raise_error(Redcord::InvalidQuery)
      else
        another_instance = klass.where(
          indexed_value: instance.indexed_value,
        ).to_a.first

        expect(another_instance.id).to eq instance.id
        expect(another_instance.indexed_value).to eq instance.indexed_value
      end
    end

    it '#find_by' do
      instance = klass.create!(indexed_value: 1)

      if cluster_mode?
        expect {
          klass.find_by(indexed_value: instance.indexed_value)
        }.to raise_error(Redcord::InvalidQuery)
      else
        another_instance = klass.find_by(indexed_value: instance.indexed_value)

        expect(another_instance.id).to eq instance.id
        expect(another_instance.indexed_value).to eq instance.indexed_value

        expect(klass.find_by(indexed_value: 0)).to be_nil
      end

    end

    context 'index set has ids of records that do not exist' do
      let(:instance_1) { klass.create!(indexed_value: 1) }
      let(:instance_2) { klass.create!(indexed_value: 1) }
      before(:each) { klass.redis.del("#{klass.model_key}:id:#{instance_2.id}") }

      it 'returns existing records, removes non-existing ids from index' do
        unless cluster_mode?
          query_set = klass.where(indexed_value: instance_1.indexed_value).to_a
          expect(query_set.size).to eq 1

          range_index_key = "#{klass.model_key}:indexed_value"
          range_index_set = klass.redis.zrangebyscore(range_index_key, 1, 1)
          expect(range_index_set.size).to eq 1
        end
      end
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

    it 'raises Redcord::RedcordDeletedError on save/update of a destroyed record' do
      instance = klass.create!(value: 1)
      expect(klass.count).to eq 1
      instance.destroy
      expect(klass.count).to eq 0

      expect {
        instance.save!
      }.to raise_error(Redcord::RedcordDeletedError)
      expect(klass.count).to eq 0

      expect {
        instance.update!(value: 2)
      }.to raise_error(Redcord::RedcordDeletedError)
      expect(klass.count).to eq 0
    end

    it 'raises other Redis::CommandErrors on save/update' do
      allow_any_instance_of(Redcord::Redis).to receive(:update_hash).and_raise(Redis::CommandError)

      instance = klass.create!(value: 1)

      expect {
        instance.save!
      }.to raise_error(Redis::CommandError)

      expect {
        instance.update!(value: 3)
      }.to raise_error(Redis::CommandError)
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
end
