# frozen_string_literal: true

# typed: false

describe Redcord::Migration::Version do
  let(:redis) { Redcord::Base.redis }
  let(:migrator) { Redcord::Migration::Migrator }
  let(:migration_file) { '20200202999999_test_migration.rb' }

  context 'when there a new migration file locally' do
    before(:each) do
      allow(Redcord::Migration::Migrator).to receive(:migration_files) do
        [migration_file]
      end
    end

    it 'needs to migrate the redis db' do
      expect(migrator.need_to_migrate?(redis.shards.first)).to be true
    end
  end

  context 'when there is no new migration file locally' do
    before(:each) do
      allow_any_instance_of(Redcord::Migration::Version).to(
        receive(:local_versions).and_return([]),
      )
      allow_any_instance_of(Redcord::Migration::Version).to(
        receive(:remote_versions).and_return([]),
      )
    end

    it 'does not need to migrate the redis db' do
      expect(migrator.need_to_migrate?(redis.shards.first)).to be false
    end
  end
end
