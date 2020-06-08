# typed: false
describe RedisRecord::Migration::Version do
  let(:redis) { RedisRecord::Base.redis }
  let(:migrator) { RedisRecord::Migration::Migrator }
  let(:migration_file) { '20200202999999_test_migration.rb' }

  before(:each) do
    redis.flushdb
  end

  context 'when there a new migration file locally' do
    before(:each) do
      allow_any_instance_of(RedisRecord::Migration::Version).to receive(:local_versions)
        .and_return([migration_file])
    end

    it 'needs to migrate the redis db' do
      expect(migrator.need_to_migrate?(redis)).to be true
    end
  end

  context 'when there is no new migration file locally' do
    before(:each) do
      allow_any_instance_of(RedisRecord::Migration::Version).to receive(:local_versions)
        .and_return([])
      allow_any_instance_of(RedisRecord::Migration::Version).to receive(:remote_versions)
        .and_return([])
    end

    it 'does not need to migrate the redis db' do
      expect(migrator.need_to_migrate?(redis)).to be false
    end
  end
end
