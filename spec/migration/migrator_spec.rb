# frozen_string_literal: true

# typed: false

describe Redcord::Migration::Migrator do
  before(:all) do
    require 'rails/all'
    require 'rake'

    class TestApplication < Rails::Application
    end

    class UserSession < T::Struct
      include Redcord::Base

      ttl 14.days

      attribute :user_id, Integer, index: true
      attribute :session_id, String, index: true
    end

    TestApplication.configure do
      config.eager_load = false
    end

    Rails.application.initialize!
    Rails.application.load_tasks
  end

  let!(:config_path) { 'config' }
  let!(:config_filename) { 'redcord.yml' }
  let!(:config_content) do
    <<~YML
      test:
        default:
          url: <%= ENV['REDIS_TEST_URL'] || 'redis://127.0.0.1:6379/1' %>
    YML
  end

  let!(:migration_path) { 'db/redcord/migrate' }
  let!(:migration_version) { '20200504000000' }
  let!(:migration_filename) { "#{migration_version}_set_user_session_ttl.rb" }
  let!(:migration_content) do
    <<~RUBY
      class SetUserSessionTtl < Redcord::Migration
        def up
          change_ttl_passive(UserSession) # 14.days
        end

        def down
        end
      end
    RUBY
  end
  let(:migrator) { Redcord::Migration::Migrator }

  around(:each) do |example|
    `mkdir -p #{config_path}`
    File.open(File.join(config_path, config_filename), 'w') do |file|
      file.write(config_content)
    end

    `mkdir -p #{migration_path}`
    File.open(File.join(migration_path, migration_filename), 'w') do |file|
      file.write(migration_content)
    end

    example.run
  ensure
    `rm -rf #{config_path}`
    `rm -rf #{migration_path}`
  end

  it 'runs migrations' do
    redis = UserSession.redis
    expect(migrator.need_to_migrate?(redis.shards.first)).to be true

    expect {
      Rake::Task['redis:migrate'].invoke
    }.to output(%r{
      redis\s+direction\s+version\s+migration\s+duration\s+
      redis://127\.0\.0\.1:6379/0\s+
      UP\s+
      #{migration_version}\s+
    }x).to_stdout

    expect(migrator.need_to_migrate?(redis.shards.first)).to be false
  end
end
