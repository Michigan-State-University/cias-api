# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/henry_ford/clinic_locations', type: :request do
  let(:user) { create(:user, :researcher, :confirmed) }
  let(:request) { get v1_henry_ford_clinic_locations_path, headers: user.create_new_auth_token }

  before do
    create_list(:clinic_location, 5)
    request
  end

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_henry_ford_clinic_locations_path }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  it 'returns correct http status' do
    expect(response).to have_http_status(:ok)
  end

  it 'return correct amount of data' do
    expect(json_response['data'].size).to eq 5
  end

  it 'has specific keys' do
    expect(json_response['data'].first.keys).to match_array(%w[id type attributes])
    expect(json_response['data'].first['attributes'].keys).to contain_exactly('name')
  end
end
