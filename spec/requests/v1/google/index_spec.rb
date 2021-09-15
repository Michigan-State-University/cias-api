# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/google/languages', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:user) { admin }
  let(:team_admin) { create(:user, :confirmed, :team_admin) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:guest) { create(:user, :confirmed, :guest) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }
  let(:organization) { create(:organization, :with_organization_admin, :with_e_intervention_admin, name: 'Oregano Public Health') }
  let(:e_intervention_admin) { organization.e_intervention_admins.first }
  let!(:language) { create(:google_language) }
  let(:roles) do
    {
      'admin' => admin,
      'e_intervention_admin' => e_intervention_admin,
      'team_admin' => team_admin,
      'researcher' => researcher
    }
  end

  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_google_languages_path, headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_google_languages_path }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when user is permitted' do
    shared_examples 'permitted user' do
      before { request }

      it 'returns proper collection size' do
        expect(json_response['data'].size).to eq(2)
      end

      it 'returns proper collection data' do
        expect(json_response['data']).to include(
          {
            'id' => '22',
            'type' => 'supported_language',
            'attributes' => {
              'language_code' => 'en',
              'language_name' => 'English'
            }
          },
          {
            'id' => language.id.to_s,
            'type' => 'supported_language',
            'attributes' => {
              'language_code' => 'fr',
              'language_name' => 'French'
            }
          }
        )
      end
    end

    context 'when user is admin' do
      it_behaves_like 'permitted user'
    end

    %w[team_admin researcher e_intervention_admin admin].each do |role|
      context "user is #{role}" do
        let(:user) { roles[role] }
        let(:headers) { user.create_new_auth_token }

        it_behaves_like 'permitted user'
      end
    end
  end

  context 'when user is not permitted' do
    shared_examples 'unpermitted user' do
      before { request }

      it 'returns proper error message' do
        expect(json_response['message']).to eq('You are not authorized to access this page.')
      end
    end

    %i[participant guest].each do |role|
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
