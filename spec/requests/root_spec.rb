# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /', type: :request do
  let(:request) { get '/' }

  context 'when system is operational' do
    before { request }

    it 'returns OK' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns system status' do
      expect(response.parsed_body).to eq('message' => 'system operational')
    end
  end

  context 'when called through Rack::Lint' do
    let(:raw_root_endpoint) { Rails.application.routes.routes.find { |route| route.path.spec.to_s == '/' }.app.app }
    let(:request) { Rack::Lint.new(raw_root_endpoint).call(Rack::MockRequest.env_for('/')) }

    it 'returns Rack 3 compliant (lowercase) header keys' do
      _status, headers, _body = request
      expect(headers.keys).to eq(['content-type'])
    end
  end
end
