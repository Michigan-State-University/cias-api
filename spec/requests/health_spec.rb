# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /api/health', type: :request do
  let(:request) { get '/api/health' }

  before { allow($redis).to receive(:ping).and_return('PONG') } # rubocop:disable Style/GlobalVars

  context 'when Postgres and Redis answer' do
    before { request }

    it 'returns OK without authentication' do
      expect(response).to have_http_status(:ok)
    end

    it 'reports both checks' do
      expect(response.parsed_body).to eq('db' => true, 'redis' => true)
    end
  end

  context 'when Postgres is unreachable' do
    before do
      connection = ActiveRecord::Base.connection
      allow(connection).to receive(:execute).and_call_original
      allow(connection).to receive(:execute).with('SELECT 1').and_raise(ActiveRecord::ConnectionNotEstablished)
      request
    end

    it 'returns service unavailable' do
      expect(response).to have_http_status(:service_unavailable)
    end

    it 'reports the failing check' do
      expect(response.parsed_body).to eq('db' => false, 'redis' => true)
    end
  end

  context 'when Redis is unreachable' do
    before do
      allow($redis).to receive(:ping).and_raise(Redis::CannotConnectError) # rubocop:disable Style/GlobalVars
      request
    end

    it 'still returns OK, so ECS keeps the tasks running' do
      expect(response).to have_http_status(:ok)
    end

    it 'reports the failing check' do
      expect(response.parsed_body).to eq('db' => true, 'redis' => false)
    end
  end
end
