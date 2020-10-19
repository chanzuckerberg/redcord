# frozen_string_literal: true

# typed: false

describe "Custom index" do
  let!(:klass) do
    Class.new(T::Struct) do
      include Redcord::Base

      attribute :value, T.nilable(Integer)
      attribute :time_value, T.nilable(Time)
      attribute :indexed_value, T.nilable(Integer), index: true
      attribute :other_value, T.nilable(Integer), index: true
      custom_index :first, [:indexed_value, :time_value, :value]
      custom_index :second, [:indexed_value, :other_value]
      if ENV['REDCORD_SPEC_USE_CLUSTER'] == 'true'
        shard_by_attribute :indexed_value
      else
        custom_index :non_cluster_index, [:time_value]
      end

      def self.name
        'RedcordSpecModel'
      end
    end
  end

  context 'custom indexes: ' do
    let!(:time_now) { Time.zone.now}
    let!(:instance) { klass.create!(indexed_value: 1, time_value: time_now) }
    let!(:instance_2) { klass.create!(indexed_value: 2, time_value: nil) }
    let!(:instance_3) { klass.create!(indexed_value: 5, time_value: time_now - 2.hours) }
    let!(:instance_4) { klass.create!(indexed_value: 5, time_value: time_now - 5.hours) }

    it 'raises an error when negative value is used for custom index attr' do
      # shared/lua_helper_methods.erb.lua: adjust_string_length
      expect { klass.create!(indexed_value: -1) }.to raise_error(Redis::CommandError)
    end

    it 'raises an error when large numbers (more than 19 digits in decimal notation) used in custom index' do
      # shared/lua_helper_methods.erb.lua: adjust_string_length
      expect { klass.create!(indexed_value: 10**19) }.to raise_error(Redis::CommandError)
      expect { klass.create!(indexed_value: 10**19 - 1) }.to_not raise_error()
    end

    it 'raises an error when inexisting custom index is queried' do
      # shared/query_helper_methods.erb.lua: validate_and_parse_query_conditions_custom
      expect { klass.where(indexed_value: 1).with_index(:third).to_a }.to raise_error(Redis::CommandError)
    end

    it 'raises error when range query conditions are used not on the last attribute in a query' do
      # shared/query_helper_methods.erb.lua: validate_and_parse_query_conditions_custom
      interval = Redcord::RangeInterval.new(min: Time.zone.now)
      expect {
        klass.where(indexed_value: 1, time_value: interval, value: 1).with_index(:first).to_a
      }.to raise_error(Redis::CommandError)
    end

    it 'raises error when attributes are in incorrect order' do
      # shared/query_helper_methods.erb.lua: validate_and_parse_query_conditions_custom
      expect {
        klass.where(indexed_value: 1, value: 1).with_index(:first).to_a
      }.to raise_error(Redis::CommandError)
    end

    it 'sorts conditions in correct order for custom index' do
      interval = Redcord::RangeInterval.new(min: time_now - 10.seconds)
      rel = klass.where(time_value: interval, indexed_value: 1).with_index(:first)
      expect(rel.count).to eq(1)
      expect(rel.to_a.size).to eq(1)
    end
    
    it 'raises error if exclusive ranges are used in a query' do
      expect {
        klass.where(indexed_value: 1, time_value: Redcord::RangeInterval.new(min: Time.zone.at(2020), min_exclusive: true)).with_index(:first)
      # Custom index doesn't support exclusive range queries
      }.to raise_error(Redcord::CustomIndexInvalidQuery)
    end

    it 'raises error when attributes are not part of specified index' do
      expect {
        klass.where(indexed_value: 1, time_value: nil, other_value: nil).with_index(:first).to_a
      }.to raise_error(Redcord::AttributeNotIndexed)
    end

    it 'creates an attribute in index content hash for custom index' do
      index_string_exists = false
      klass.redis.scan_each_shard("#{klass.model_key}:custom_index:first_content*") do |key|
        index_string_exists ||= klass.redis.hget(key, instance.id).is_a?(String)
      end
      expect(index_string_exists).to be(true)
    end
    
    it 'returns instance by int attribute query' do
      expect(klass.where(indexed_value: 1).with_index(:first).to_a.first.id).to eq(instance.id)
    end

    it 'returns count by int attribute query' do
      expect(klass.where(indexed_value: 1).with_index(:first).count).to eq(1)
      expect(klass.where(indexed_value: 3).with_index(:first).count).to eq(0)
    end

    it 'returns instance by time attribute range query' do
      interval = Redcord::RangeInterval.new(min: time_now - 10.seconds)
      unless ENV['REDCORD_SPEC_USE_CLUSTER'] == 'true'
        expect(klass.where(time_value: interval).with_index(:non_cluster_index).to_a.first.id).to eq(instance.id)
      end
    end

    it 'returns instance by attribute is nil query' do
      unless ENV['REDCORD_SPEC_USE_CLUSTER'] == 'true'
        expect(klass.where(time_value: nil).with_index(:non_cluster_index).to_a.first.id).to eq(instance_2.id)
      end
    end

    it 'returns instance by int and time attributes range query' do
      interval = Redcord::RangeInterval.new(min: time_now - 10.seconds)
      expect(klass.where(indexed_value: 1, time_value: interval).with_index(:first).to_a.first.id).to eq(instance.id)
    end

    it 'returns instance by int and time attributes is nil query' do
      expect(klass.where(indexed_value: 2, time_value: nil).with_index(:first).to_a.first.id).to eq(instance_2.id)
    end

    it 'returns selected attributes' do
      expect(klass.where(indexed_value: 1).with_index(:first).select(:time_value).first[:time_value].to_i).to eq(instance.time_value.to_i)
    end

    it 'cleans up custom index after deleting record' do
      instance_id = instance.id
      instance.destroy
      expect(klass.where(indexed_value: 1).with_index(:first).count).to eq(0)
      index_string_exists = false
      klass.redis.scan_each_shard("#{klass.model_key}:custom_index:first_content*") do |key|
        index_string_exists ||= klass.redis.hget(key, instance.id).is_a?(String)
      end
      expect(index_string_exists).to be(false)
    end

    it 'updates custom index on record update' do
      interval = Redcord::RangeInterval.new(min: time_now - 10.seconds)
      expect(klass.where(indexed_value: 2, time_value: interval).with_index(:first).count).to eq(0)
      expect(klass.where(time_value: interval).with_index(:non_cluster_index).count).to eq(1) unless ENV['REDCORD_SPEC_USE_CLUSTER'] == 'true'
      instance_2.update!(time_value: time_now)
      expect(klass.where(indexed_value: 2, time_value: interval).with_index(:first).count).to eq(1)
      expect(klass.where(time_value: interval).with_index(:non_cluster_index).count).to eq(2) unless ENV['REDCORD_SPEC_USE_CLUSTER'] == 'true'
    end

    it 'retrives results when using query building' do
      rel1 = klass.where(indexed_value: 5)
      expect(rel1.with_index(:first).to_a.size).to eq(2)
      interval = Redcord::RangeInterval.new(min: time_now - 3.hours)
      rel2 = rel1.where(time_value: interval)
      expect(rel2.with_index(:first).to_a.size).to eq(1)
    end

    it 'allows adding conditions to relations after setting index' do
      rel1 = klass.where(indexed_value: 5).with_index(:first)
      expect(rel1.count).to eq(2)
      interval = Redcord::RangeInterval.new(min: time_now - 3.hours)
      rel2 = rel1.where(time_value: interval)
      expect(rel2.count).to eq(1)
    end

    it 'allows changing index in relation' do
      rel = klass.where(indexed_value: 5, other_value: nil)
      rel.with_index(:first)
      expect { rel.to_a.size }.to raise_error(Redcord::AttributeNotIndexed)
      rel.with_index(:second)
      expect(rel.custom_index_name).to eq(:second)
      expect(rel.to_a.size).to eq(2)
      rel.with_index(nil)
      expect(rel.custom_index_name).to be(nil)
      expect(rel.to_a.size).to eq(2)
    end

    context 'all attributes are nilable' do
      klass = Class.new(T::Struct) do
        include Redcord::Base
        attribute :a, T.nilable(Integer), index: true
        attribute :b, T.nilable(Integer)
        attribute :c, T.nilable(Integer)
        custom_index :first, [:a, :b, :c]
        if ENV['REDCORD_SPEC_USE_CLUSTER'] == 'true'
          shard_by_attribute :a
        end

        def self.name
          'RedcordSpecModelOther'
        end
      end

      it 'creates and indexes instance with all nil attributes with create!' do
        unless ENV['REDCORD_SPEC_USE_CLUSTER'] == 'true'
          klass.create!({})
          expect(klass.where(a: nil, b: nil).with_index(:first).count).to eq(1)
        end
      end

      it 'creates and indexes instance with all nil attributes with save!' do
        unless ENV['REDCORD_SPEC_USE_CLUSTER'] == 'true'
          instance = klass.new({})
          instance.save!
          expect(klass.where(a: nil, b: nil).with_index(:first).count).to eq(1)
        end
      end
    end
  end
end
