# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HealthCheck do
  let(:result)        { described_class.new.call({})  }
  let(:status)        { result.first                  }
  let(:json_response) { JSON.parse(result.last.first) }

  describe '#call' do
    context 'when all systems are operational' do
      it 'returns 200 response' do
        expect(status).to eq 200
      end

      it 'return system details in json response' do
        expect(json_response).to eq({ 'database' => true })
      end
    end

    context 'when database is not operational' do
      before do
        expect(ActiveRecord::Base.connection)
          .to receive(:execute)
                .and_raise(ActiveRecord::StatementInvalid)
      end

      it 'returns 200 response' do
        expect(status).to eq 200
      end

      it 'return system details in json response' do
        expect(json_response).to eq({ 'database' => false })
      end
    end
  end
end
