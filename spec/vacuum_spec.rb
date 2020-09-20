# frozen_string_literal: true

# typed: false

describe Redcord::VacuumHelper do
  let!(:klass) do
    Class.new(T::Struct) do
      include Redcord::Base

      attribute :a, T.nilable(String), index: true
      attribute :b, T.nilable(Integer), index: true

      def self.name
        'RedcordVacuumSpecModel'
      end
    end
  end

  before(:each) do
    klass.establish_connection
  end

  context 'vacuum' do
    it 'vacuums all index attributes' do
      instance = klass.create!(a: "x", b: 1)
      # index sets should contain the id
      expect(klass.redis.sismember("#{klass.model_key}:a:#{instance.a}", instance.id)).to be true
      expect(klass.redis.zscore("#{klass.model_key}:b", instance.id)).to eq 1

      klass.redis.del("#{klass.model_key}:id:#{instance.id}")
      # After deleting the key and vacuuming, index sets should be updated
      Redcord::VacuumHelper.vacuum(klass)
      expect(klass.redis.sismember("#{klass.model_key}:a:#{instance.a}", instance.id)).to be false
      expect(klass.redis.zscore("#{klass.model_key}:b", instance.id)).to be_nil
    end

    it 'vacuums range index attributes with nil values' do
      instance = klass.create!(b: nil)
      # index sets should contain the id
      expect(klass.redis.sismember("#{klass.model_key}:b:", instance.id)).to be true

      # After deleting the key and vacuuming, index sets should be updated
      Redcord::VacuumHelper.vacuum(klass)
      expect(klass.redis.sismember("#{klass.model_key}:b:", instance.id)).to be true
    end
  end
end
