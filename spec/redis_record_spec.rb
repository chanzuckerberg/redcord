# typed: false
describe Redcord do
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

      expect(klass.where(a: 0).count).to eq 0
    end
  end
end
