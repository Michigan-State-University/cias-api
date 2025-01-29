# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rack::HealthCheck', type: :request do
  describe 'GET /health_check' do
    include Rack::Test::Methods

    let(:app) do
      Rack::Builder.parse_file(Rails.root.join('config.ru').to_s)
    end

    before { get '/health_check' }

    it 'returns 200 response' do
      expect(last_response.status).to eq 200
    end

    it 'return system details in json response' do
      expect(JSON.parse(last_response.body)).to eq({ 'database' => true, 'redis' => true })
    end
  end
end
