# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/organizations/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }

  let!(:organization) { create(:organization, name: 'Michigan Public Health') }
  let!(:organization_1) { create(:organization, name: 'Oregano Public Health') }

  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_organization_path(organization.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_organization_path(organization.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when user is permitted' do
    shared_examples 'permitted user' do
      before { request }

      it 'returns proper data' do
        expect(json_response['data']).to include(
          {
            'id' => organization.id.to_s,
            'type' => 'organization',
            'attributes' => {
              'name' => organization.name
            }
          }
        )
      end

      it 'returns proper collection size' do
        expect(json_response.size).to eq(1)
      end
    end

    context 'when user is admin' do
      it_behaves_like 'permitted user'
    end
  end

  context 'when user is not permitted' do
    shared_examples 'unpermitted user' do
      before { request }

      it 'returns proper error message' do
        expect(json_response['message']).to eq('You are not authorized to access this page.')
      end
    end

    %i[team_admin researcher participant guest].each do |role|
      context "user is #{role}" do
        let(:user) { create(:user, :confirmed, role) }
        let(:headers) { user.create_new_auth_token }

        it_behaves_like 'unpermitted user'
      end
    end

    context 'when user is preview user' do
      let(:headers) { preview_user.create_new_auth_token }

      before { request }

      it 'returns proper error message' do
        expect(json_response['message']).to eq('Couldn\'t find Session without an ID')
      end
    end
  end
end
