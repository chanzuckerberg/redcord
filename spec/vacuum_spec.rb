# frozen_string_literal: true

# typed: false

describe Redcord::VacuumHelper do
  class RedcordVacuumSpecModel < T::Struct
    include Redcord::Base

    attribute :a, T.nilable(String), index: !cluster_mode?
    attribute :b, T.nilable(Integer), index: true

    shard_by_attribute :a if cluster_mode?
  end

  let(:model_key) { RedcordVacuumSpecModel.model_key }

  context 'vacuum' do
    it 'vacuums all index attributes' do
      instance = RedcordVacuumSpecModel.create!(a: "x", b: 1)
      RedcordVacuumSpecModel.create!(a: "x", b: nil)
      # index sets should contain the id
      unless cluster_mode?
        expect(
          RedcordVacuumSpecModel.redis.sismember("#{model_key}:a:#{instance.a}#{instance.hash_tag}", instance.id)
        ).to be true
      end
      expect(
        RedcordVacuumSpecModel.redis.zscore("#{model_key}:b#{instance.hash_tag}", instance.id)
      ).to eq 1

       # An expired record due to TTL
      RedcordVacuumSpecModel.redis.del("#{model_key}:id:#{instance.id}")

      # After vacuuming, index sets should be updated
      Redcord::VacuumHelper.vacuum(RedcordVacuumSpecModel)
      expect(RedcordVacuumSpecModel.redis.sismember("#{model_key}:a:#{instance.a}#{instance.hash_tag}", instance.id)).to be false
      expect(RedcordVacuumSpecModel.redis.zscore("#{model_key}:b#{instance.hash_tag}", instance.id)).to be_nil
    end

    it 'vacuums range index attributes with nil values' do
      instance = RedcordVacuumSpecModel.create!(b: nil)
      # The nil range index set should contain the id
      expect(RedcordVacuumSpecModel.redis.sismember("#{model_key}:b:#{instance.hash_tag}", instance.id)).to be true

      # An expired record due to TTL
      RedcordVacuumSpecModel.redis.del("#{model_key}:id:#{instance.id}")

      # After vacuuming, nil range index set should be updated
      Redcord::VacuumHelper.vacuum(RedcordVacuumSpecModel)
      expect(RedcordVacuumSpecModel.redis.sismember("#{model_key}:b:#{instance.hash_tag}", instance.id)).to be false
    end

    context 'custom index' do
      let!(:klass) do
        Class.new(T::Struct) do
          include Redcord::Base
          attribute :a, T.nilable(Integer), index: !cluster_mode?
          attribute :b, T.nilable(Integer)
          custom_index :first, [:a, :b]

          shard_by_attribute :a if cluster_mode?

          def self.name
            'RedcordVacuumSpecModelCustom'
          end
        end
      end

      it 'vacuums custom index for non existing records' do
        instance = klass.create!(a: 1, b: 2)
        # Creates records in custom index and in custom index content hash
        index_key = "#{klass.model_key}:custom_index:first#{instance.hash_tag}"
        index_content_key = "#{klass.model_key}:custom_index:first_content#{instance.hash_tag}"
        index_string = klass.redis.hget(index_content_key, instance.id)
        expect(index_string).to be_kind_of(String)
        expect(klass.redis.zrangebylex(index_key, "[#{index_string}", "[#{index_string}").size).to eq(1)

        # An expired record due to TTL
        klass.redis.del("#{klass.model_key}:id:#{instance.id}")

        # After vacuuming, custom indices should be updated
        Redcord::VacuumHelper.vacuum(klass)
        index_string_new = klass.redis.hget(index_content_key, instance.id)
        expect(index_string_new).to be(nil)
        expect(klass.redis.zrangebylex(index_key, "[#{index_string}", "[#{index_string}").size).to eq(0)
      end
    end
  end
end
