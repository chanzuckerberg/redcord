# typed: ignore

describe Redcord::ConnectionPool do
  let!(:klass) do
    Class.new(T::Struct) do
      include Redcord::Base

      attribute :value, Integer

      def self.name
        'spec_model_2'
      end
    end
  end

  it 'delegates methods' do
    env = Rails.env
    allow(Redcord::Base).to receive(:configurations).and_return(
      {
        env => {
          'spec_model_2' => {
            'pool' => 5
          },
        },
      },
    )
    klass.establish_connection
    expect(klass.redis).to be_a(Redcord::ConnectionPool)
    expect(klass.redis).to receive(:create_hash_returning_id).and_call_original
    expect(klass.redis).to receive(:hgetall).and_call_original

    record = klass.create!(value: 1)
    klass.find(record.id)
  end
end