# frozen_string_literal: true

# typed: false

describe Redcord::Actions do
  let!(:klass) do
    Class.new(T::Struct) do
      include Redcord::Base

      attribute :value, T.nilable(Integer)
      attribute :indexed_value, T.nilable(Integer), index: true

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
    end

    it 'validates types' do
      # TODO: this should raise an error
      klass.create!(value: '1')
    end

    it 'errors when id overflows a 64 bit signed integer' do
      Redcord::Base.redis.set("#{klass.model_key}:id_seq", 2**63 - 2)

      instance = klass.create!(value: nil)
      expect(instance.id).to eq(2**63 - 1)

      expect {
        klass.create!(value: nil)
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
      instance.save!

      expect(instance.created_at).not_to be_nil
      expect(instance.updated_at).not_to be_nil

      another_instance = klass.find(instance.id)
      expect(instance.value).to eq another_instance.value
    end

    it 'doesn\'t update redis until save!/update! is called' do
      instance = klass.create!(value: 3)
      instance.value = 4

      another_instance = klass.find(instance.id)
      expect(another_instance.value).to eq 3

      instance.save!
      another_instance = klass.find(instance.id)
      expect(another_instance.value).to eq instance.value
    end

    it 'resets ttl' do
      instance = klass.create!(value: 3)

      klass.ttl(2.days)
      migrator.change_ttl_passive(klass)
      expect(klass.redis.ttl(instance.instance_key)).to eq(-1)

      instance.save!
      expect(klass.redis.ttl(instance.instance_key) > 0).to be true

      klass.ttl(nil)
      migrator.change_ttl_passive(klass)
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
        klass.find(non_existing_id)
      }.to raise_error(Redcord::RecordNotFound)

      instance = klass.create!(value: 1)

      another_instance = klass.find(instance.id)

      # It validates types
      expect {
        klass.find(another_instance.id.to_s)
      }.to raise_error(TypeError)

      expect(another_instance.id).to eq instance.id
      expect(another_instance.value).to eq instance.value
    end

    it '#where' do
      klass.establish_connection

      instance = klass.create!(indexed_value: 1)
      another_instance = klass.where(
        indexed_value: instance.indexed_value,
      ).to_a.first

      expect(another_instance.id).to eq instance.id
      expect(another_instance.indexed_value).to eq instance.indexed_value
    end

    it '#find_by' do
      klass.establish_connection

      instance = klass.create!(indexed_value: 1)
      another_instance = klass.find_by(indexed_value: instance.indexed_value)

      expect(another_instance.id).to eq instance.id
      expect(another_instance.indexed_value).to eq instance.indexed_value

      expect(klass.find_by(indexed_value: 0)).to be_nil
      expect(klass.find_by(id: instance.id)).to_not be_nil
      expect(klass.find_by(
        id: instance.id,
        indexed_value: instance.indexed_value,
      )).to_not be_nil
    end
  end

  context 'delete' do
    it '#destroy' do
      instance = klass.create!(value: 1)

      another_instance = klass.find(instance.id)
      expect(another_instance.id).to eq instance.id
      expect(another_instance.value).to eq instance.value
      expect(another_instance.created_at.to_i).to eq instance.created_at.to_i
      expect(another_instance.updated_at.to_i).to eq instance.updated_at.to_i

      instance.destroy
      expect {
        klass.find(instance.id)
      }.to raise_error(Redcord::RecordNotFound)
    end

    it 'does not save/update a destroyed record' do
      instance = klass.create!(value: 1)
      instance.destroy

      expect {
        instance.save!
      }.to raise_error(Redis::CommandError)

      expect {
        instance.update!(value: 2)
      }.to raise_error(Redis::CommandError)
    end

    it 'deletes a non-existing record' do
      instance = klass.new(value: 1)
      expect(instance.id).to be_nil
      expect {
        instance.destroy
      }.to_not raise_error
    end
  end
end
