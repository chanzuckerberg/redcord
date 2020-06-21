# typed: false
describe Redcord do
  include Redcord::Migration::TTL

  context 'redis connection' do
    let!(:model_class) do
      Class.new(T::Struct) do
        include Redcord::Base

        def self.name
          'spec_model'
        end
      end
    end
    let(:env) { 'my_env' }

    around(:each) do |test_example|
      config = Redcord::Base.configurations
      test_example.run
    ensure
      Redcord::Base.configurations = config
      model_class.establish_connection
    end

    it 'uses configurations to establish Redis connections' do
      fake_url = 'redis://test.fakeurl/1'
      allow(Rails).to receive(:env).and_return(env)
      allow(Redcord::Base).to receive(:configurations).and_return({
        env => {'spec_model' => {'url' => fake_url}},
      })

      expect {
        model_class.establish_connection
      }.to raise_error(Redis::CannotConnectError)
    end

    it 'establishes Redis connection' do
      expect(model_class.redis.ping).to eq 'PONG'
    end

    it 'shares the base connection config by default' do
      expect(model_class.connection_config).to eq Redcord::Base.connection_config
    end

    it 'can have a different connection at model level' do
      model_class.redis = Redis.new
      expect(model_class.redis).to_not eq Redcord::Base.redis
    end
  end

  it 'defines props' do
    klass = Class.new(T::Struct) do
      include Redcord::Base

      attribute :a, Integer
    end

    instance = klass.new(a: 1)
    expect(instance.methods.include?(:a)).to be true
    expect(instance.methods.include?(:a=)).to be true
    expect(instance.id).to be_nil
  end

  context 'scripts' do
    it 'creates a hash and increases the id' do
      expect(Redcord::Base.redis.create_hash_returning_id('test', {a: 1})).to eq 1
      expect(Redcord::Base.redis.hgetall('test:id:1')).to eq({'a' => '1'})

      expect(Redcord::Base.redis.create_hash_returning_id('test', {b: 2})).to eq 2
      expect(Redcord::Base.redis.hgetall('test:id:2')).to eq({'b' => '2'})
    end

    it 'errors when id overflows a 64 bit signed integer' do
      Redcord::Base.redis.set('test:id_seq', 2 ** 63 - 2)
      expect(Redcord::Base.redis.create_hash_returning_id('test', {b: 2})).to eq(2 ** 63 - 1)
      expect {
        Redcord::Base.redis.create_hash_returning_id('test', {c: 3})
      }.to raise_error(Redis::CommandError)
    end
  end

  context 'CRUD options' do
    let(:klass) do
      Class.new(T::Struct) do
        include Redcord::Base

        attribute :value, Integer

        def self.name
          'RedcordSpecModel'
        end
      end
    end

    it 'reads and deletes' do
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

      # save and update will fail if the record has been deleted
      expect {
        instance.save!
      }.to raise_error(Redis::CommandError)

      expect {
        instance.update!(value: 2)
      }.to raise_error(Redis::CommandError)

      instance = klass.new(value: 1)
      expect(instance.id).to be_nil
      expect {
        instance.destroy
      }.to_not raise_error
    end

    it 'creates, saves and updates' do
      instance = klass.create!(value: 3)
      expect(instance.value).to eq 3

      expect {
        instance.value = '4'
      }.to raise_error(TypeError)

      instance.update!(value: 4)
      expect(instance.value).to eq 4

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

      instance = klass.new(value: 3)
      instance.update!(value: 4)
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

    it 'resets ttl when saves or updates' do
      instance = klass.create!(value: 3)

      klass.ttl(2.days)
      change_ttl_passive(klass)
      expect(klass.redis.ttl(instance.instance_key)).to eq -1

      instance.save!
      expect(klass.redis.ttl(instance.instance_key) > 0).to be true

      klass.ttl(nil)
      change_ttl_passive(klass)
      instance.update!(value: 4)
      expect(klass.redis.ttl(instance.instance_key)).to eq -1
    end
  end

  context 'Index attribute operations' do
    let(:klass) do
      Class.new(T::Struct) do
        include Redcord::Base

        attribute :a, Integer, index: true
        attribute :b, String, index: true
        attribute :c, Integer
        attribute :d, T.nilable(Time), index: true
        def self.name
          'RedcordSpecModel2'
        end
      end
    end

    before(:each) do
      klass.establish_connection
    end

    it 'creates index id sets after creation' do
      first = klass.create!(a: 3, b: "3", c: 3)
      second = klass.create!(a: 2, b: "2", c: 3)

      # Query using normal index attributes
      queried_instances = klass.where(b: "3").to_a
      expect(queried_instances.size).to eq 1
      expect(queried_instances[0].id).to eq first.id

      # Query using range index attributes
      queried_instances = klass.where(a: 3).to_a
      expect(queried_instances.size).to eq 1
      expect(queried_instances[0].id).to eq first.id

      queried_instances = klass.where(a: Redcord::RangeInterval.new(max: 5)).to_a
      expect(queried_instances.size).to eq 2
      expect(queried_instances[0].id).to eq(first.id).or eq(second.id)
      expect(queried_instances[1].id).to eq(first.id).or eq(second.id)

      # Query using range index attributes with closed interval
      queried_instances = klass.where(a: Redcord::RangeInterval.new(max: 3, max_exclusive: true)).to_a
      expect(queried_instances.size).to eq 1
      expect(queried_instances[0].id).to eq(second.id)

      queried_instances = klass.where(a: Redcord::RangeInterval.new(min: 2, min_exclusive: true)).to_a
      expect(queried_instances.size).to eq 1
      expect(queried_instances[0].id).to eq(first.id)
    end

    it 'allows queries for multiple index attributes' do
      first = klass.create!(a: 3, b: "3", c: 3)
      second = klass.create!(a: 3, b: "4", c: 3)

      # query with one attribute should return both values
      queried_instances = klass.where(a: 3).to_a
      expect(queried_instances.size).to eq 2
      expect(queried_instances[0].id).to eq(first.id).or eq(second.id)
      expect(queried_instances[1].id).to eq(first.id).or eq(second.id)

      queried_instances = klass.where(a: 3, b: "3").to_a
      expect(queried_instances.size).to eq 1
      expect(queried_instances[0].id).to eq first.id
    end

    it 'allows combining range and equality conditions in queries' do
      first = klass.create!(a: 3, b: "3", c: 3)
      second = klass.create!(a: 1, b: "4", c: 3)

      queried_instances = klass.where(a: Redcord::RangeInterval.new(max: 5), b: "3").to_a
      expect(queried_instances.size).to eq 1
      expect(queried_instances[0].id).to eq first.id

      queried_instances = klass.where(a: Redcord::RangeInterval.new(max: 3), b: "2").to_a
      expect(queried_instances.size).to eq 0

      queried_instances = klass.where(a: Redcord::RangeInterval.new(min: 5), b: "4").to_a
      expect(queried_instances.size).to eq 0
    end

    it 'allows time types to be range index attributes' do
      first = klass.create!(a: 3, b: "3", c: 3, d: Time.zone.now - 1.hour)
      second = klass.create!(a: 3, b: "3", c: 3, d: Time.zone.now)

      queried_instances = klass.where(d: Redcord::RangeInterval.new(max: Time.zone.now + 1.day)).to_a
      expect(queried_instances.size).to eq 2
      expect(queried_instances[0].id).to eq(first.id).or eq(second.id)
      expect(queried_instances[1].id).to eq(first.id).or eq(second.id)
    end

    it 'allows nil values for range index attributes' do
      first = klass.create!(a: 3, b: "3", c: 3, d: nil)

      queried_instances = klass.where(d: nil).to_a
      expect(queried_instances.size).to eq 1
      expect(queried_instances[0].id).to eq first.id
    end

    it 'maintains index id sets after an update operation' do
      instance = klass.create!(a: 3, b: "3", c: 3)
      instance.update!(a: 4)

      # query for previous value of a should be empty, and new value should be updated.
      queried_instances = klass.where(a: 3).to_a
      expect(queried_instances.size).to eq 0

      queried_instances = klass.where(a: 4).to_a
      expect(queried_instances.size).to eq 1
      expect(queried_instances[0].id).to eq instance.id

      # other index attributes not changed should be untouched
      queried_instances = klass.where(b: "3").to_a
      expect(queried_instances.size).to eq 1
      expect(queried_instances[0].id).to eq instance.id
    end

    it 'maintains index id sets after delete operation' do
      instance = klass.create!(a: 3, b: "3", c: 3)
      instance.destroy

      queried_instances = klass.where(a: 3).to_a
      expect(queried_instances.size).to eq 0
    end

    it 'throws an error when given an attribute that is not indexed' do
      instance = klass.create!(a: 3, b: "3", c: 3)
      expect {
        klass.where(c: 3).to_a
      }.to raise_error(Redcord::AttributeNotIndexed)
    end

    it 'throws an error when given an attribute of the wrong type' do
      instance = klass.create!(a: 3, b: "3", c: 3)

      expect {
        klass.where(a: "3").to_a
      }.to raise_error(Redcord::WrongAttributeType)
      expect {
        klass.where(a: Redcord::RangeInterval.new(min: 1, max: 5.0)).to_a
      }.to raise_error(Redcord::WrongAttributeType)
    end

    it 'supports chaining select index query method' do
      first = klass.create!(a: 3, b: "3", c: 3)
      second = klass.create!(a: 3, b: "4", c: 3)

      queried_instances = klass.where(a: 3, b: "3").select(:c).to_a
      expect(queried_instances.size).to eq 1
      expect(queried_instances[0][:id]).to eq(first.id)
      expect(queried_instances[0][:a]).to be_nil
      expect(queried_instances[0][:b]).to be_nil
      expect(queried_instances[0][:c]).to eq(3)
    end

    it 'does not chain the select method if a block is given' do
      first = klass.create!(a: 3, b: "3", c: 3)
      second = klass.create!(a: 3, b: "4", c: 3)

      queried_instances = klass.where(a: 3).select{ |r| r.b == "3" }
      expect(queried_instances.size).to eq 1
      expect(queried_instances[0].id).to eq(first.id)
    end

    it 'supports chaining count index query method' do
      first = klass.create!(a: 3, b: "3", c: 3)
      second = klass.create!(a: 3, b: "4", c: 3)

      count = klass.where(a: 3).count
      expect(count).to eq 2
    end
  end
end
