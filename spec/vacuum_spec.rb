# frozen_string_literal: true

# typed: false

describe Redcord::VacuumHelper do
  class RedcordVacuumSpecModel < T::Struct
    include Redcord::Base

    attribute :a, T.nilable(String), index: true
    attribute :b, T.nilable(Integer), index: true
  end

  let (:model_key) { RedcordVacuumSpecModel.model_key }

  context 'vacuum' do
    it 'vacuums all index attributes' do
      instance = RedcordVacuumSpecModel.create!(a: "x", b: 1)
      # index sets should contain the id
      expect(
        RedcordVacuumSpecModel.redis.sismember("#{model_key}:a:#{instance.a}", instance.id)
      ).to be true
      expect(
        RedcordVacuumSpecModel.redis.zscore("#{model_key}:b", instance.id)
      ).to eq 1

       # An expired record due to TTL
      RedcordVacuumSpecModel.redis.del("#{model_key}:id:#{instance.id}")

      # After vacuuming, index sets should be updated
      Redcord::VacuumHelper.vacuum(RedcordVacuumSpecModel)
      expect(RedcordVacuumSpecModel.redis.sismember("#{model_key}:a:#{instance.a}", instance.id)).to be false
      expect(RedcordVacuumSpecModel.redis.zscore("#{model_key}:b", instance.id)).to be_nil
    end

    it 'vacuums range index attributes with nil values' do
      instance = RedcordVacuumSpecModel.create!(b: nil)
      # The nil range index set should contain the id
      expect(RedcordVacuumSpecModel.redis.sismember("#{model_key}:b:", instance.id)).to be true

      # An expired record due to TTL
      RedcordVacuumSpecModel.redis.del("#{model_key}:id:#{instance.id}")

      # After vacuuming, nil range index set should be updated
      Redcord::VacuumHelper.vacuum(RedcordVacuumSpecModel)
      expect(RedcordVacuumSpecModel.redis.sismember("#{model_key}:b:", instance.id)).to be false
    end
  end
end
