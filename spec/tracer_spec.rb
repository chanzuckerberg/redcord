# frozen_string_literal: true


describe Redcord::Tracer do
  class FakeTracer
    def trace(*)
      yield
    end
  end

  context 'when tracer is set' do
    include Redcord::Tracer::ClassMethods

    let(:tracer) { proc { FakeTracer.new } }

    it 'records traces' do
      counter = 0

      expect(
        trace('test', model_name: 'test') { counter += 1 }
      ).to be 1
      expect(counter).to be 1
    end
  end

  context 'when tracer is not set' do
    include Redcord::Tracer::ClassMethods

    let(:tracer) { nil }

    it 'does not record traces' do
      counter = 0
      expect(
        trace('test', model_name: 'test') { counter += 2 }
      ).to be 2
      expect(counter).to be 2
    end
  end
end
