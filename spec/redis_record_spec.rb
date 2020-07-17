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
