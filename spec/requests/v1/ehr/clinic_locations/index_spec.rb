# frozen_string_literal: true

require 'rails_helper'

# /v1/ehr/clinic_locations is the site-neutral path of the same action; /v1/henry_ford/clinic_locations
# stays for one release.
RSpec.describe 'GET /v1/henry_ford/clinic_locations and GET /v1/ehr/clinic_locations', type: :request do
  %w[/v1/henry_ford/clinic_locations /v1/ehr/clinic_locations].each do |path|
    context "via #{path}" do
      let(:user) { create(:user, :researcher, :confirmed) }
      let(:request) { get path, headers: user.create_new_auth_token }

      before do
        create_list(:clinic_location, 5)
        request
      end

      context 'when auth' do
        context 'is invalid' do
          let(:request) { get path }

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

      context 'when the user may not read interventions' do
        let(:user) { create(:user, :third_party, :confirmed) }

        it { expect(response).to have_http_status(:forbidden) }
      end
    end
  end
end
