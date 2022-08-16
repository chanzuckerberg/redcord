# frozen_string_literal: true


describe Redcord::RedisConnection do
  let!(:model_class) do
    Class.new(T::Struct) do
      include Redcord::Base

      def self.name
        'spec_model'
      end
    end
  end
  let!(:env) { 'my_env' }

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
    allow(Redcord::Base).to receive(:configurations).and_return(
      {
        env => {
          'spec_model' => {
            'url' => fake_url,
          },
        },
      },
    )

    expect {
      model_class.establish_connection
    }.to raise_error(Redis::CannotConnectError)
  end

  it 'uses a connection pool if pool size is specified in configurations' do
    allow(Rails).to receive(:env).and_return(env)
    allow(Redcord::Base).to receive(:configurations).and_return(
      {
        env => {
          'spec_model' => {
            'pool' => 5
          },
        },
      },
    )
    model_class.establish_connection
    expect(model_class.redis).to be_a(Redcord::ConnectionPool)
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

describe Redcord do
  class ModelClass0 < T::Struct
    include Redcord::Base

    def self.name
      'spec_model0'
    end
  end
  class ModelClass1 < T::Struct
    include Redcord::Base

    def self.name
      'spec_model1'
    end
  end
  let!(:env) { 'my_env' }

  around(:each) do |test_example|
    config = Redcord::Base.configurations
    test_example.run
  ensure
    Redcord::Base.configurations = config
  end


  it 'can find all descendants' do
    expect(Redcord::Base.descendants).to include(ModelClass0)
    expect(Redcord::Base.descendants).to include(ModelClass1)
  end


  it 'can reestablish all connections' do
    expect(ModelClass0).to receive(:establish_connection)
    expect(ModelClass1).to receive(:establish_connection)
    Redcord.establish_connections
  end
end
