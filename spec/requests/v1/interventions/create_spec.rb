# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:user_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant researcher guest]) }
  let(:guest) { create(:user, :guest) }
  let(:user) { admin }
  let(:headers) { user.create_new_auth_token }
  let(:organization) { create(:organization) }
  let(:users) do
    {
      'researcher' => researcher,
      'user_with_multiple_roles' => user_with_multiple_roles
    }
  end

  let(:params) do
    {
      intervention: {
        name: 'New Intervention',
        organization_id: organization.id
      }
    }
  end
  let(:request) { post v1_interventions_path, params: params, headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { post v1_interventions_path }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'is response header Content-Type eq JSON' do
    before { request }

    it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
  end

  context 'when user has role admin' do
    before { request }

    context 'when params are VALID' do
      it { expect(response).to have_http_status(:created) }

      it 'response contains proper attributes' do
        expect(json_response['data']['attributes']).to include(
          'name' => '[Reporting] New Intervention',
          'status' => 'draft',
          'shared_to' => 'anyone',
          'language_name' => 'English',
          'language_code' => 'en'
        )
      end

      it 'creates a intervention object' do
        expect(Intervention.last.attributes).to include(
          'name' => '[Reporting] New Intervention',
          'user_id' => admin.id,
          'status' => 'draft',
          'shared_to' => 'anyone',
          'organization_id' => organization.id,
          'google_language_id' => 22
        )
      end
    end

    context 'when params are INVALID' do
      let(:params) do
        {
          intervention: {
            name: ''
          }
        }
      end

      it { expect(response).to have_http_status(:unprocessable_entity) }

      it 'response contains proper error message' do
        expect(json_response['message']).to eq "Validation failed: Name can't be blank"
      end

      it 'does not create a intervention object' do
        expect(Intervention.all.size).to eq 0
      end
    end
  end

  context 'when user has role researcher and wan\'t assign intervention to organization' do
    let(:user) { researcher }
    let(:params) do
      {
        intervention: {
          name: 'New Intervention'
        }
      }
    end

    before { request }

    context 'when params are VALID' do
      it { expect(response).to have_http_status(:created) }

      it 'response contains proper attributes' do
        expect(json_response['data']['attributes']).to include(
          'name' => 'New Intervention',
          'status' => 'draft',
          'shared_to' => 'anyone'
        )
      end

      it 'creates a intervention object' do
        expect(Intervention.last.attributes).to include(
          'name' => 'New Intervention',
          'user_id' => researcher.id,
          'status' => 'draft',
          'shared_to' => 'anyone'
        )
      end
    end

    context 'when params are INVALID' do
      let(:params) do
        {
          intervention: {
            name: ''
          }
        }
      end

      it { expect(response).to have_http_status(:unprocessable_entity) }

      it 'response contains proper error message' do
        expect(json_response['message']).to eq "Validation failed: Name can't be blank"
      end

      it 'does not create a intervention object' do
        expect(Intervention.all.size).to eq 0
      end
    end
  end

  context 'when one of the roles is researcher' do
    shared_examples 'permitted user' do
      before { request }

      context 'when params are VALID' do
        it { expect(response).to have_http_status(:created) }

        it 'response contains proper attributes' do
          expect(json_response['data']['attributes']).to include(
            'name' => '[Reporting] New Intervention',
            'status' => 'draft',
            'shared_to' => 'anyone'
          )
        end

        it 'creates a intervention object' do
          expect(Intervention.last.attributes).to include(
            'name' => '[Reporting] New Intervention',
            'user_id' => user.id,
            'status' => 'draft',
            'shared_to' => 'anyone'
          )
        end
      end

      context 'when params are INVALID' do
        let(:params) do
          {
            intervention: {
              name: ''
            }
          }
        end

        it { expect(response).to have_http_status(:unprocessable_entity) }

        it 'response contains proper error message' do
          expect(json_response['message']).to eq "Validation failed: Name can't be blank"
        end

        it 'does not create a intervention object' do
          expect(Intervention.all.size).to eq 0
        end
      end
    end

    context 'user is researcher' do
      let(:user) { researcher }

      it_behaves_like 'permitted user'
    end

    context 'user is one of the roles is researcher' do
      let(:user) { user_with_multiple_roles }

      it_behaves_like 'permitted user'
    end
  end

  context 'when user has role participant' do
    let(:user) { participant }

    before { request }

    it { expect(response).to have_http_status(:forbidden) }

    it 'response contains proper error message' do
      expect(json_response['message']).to eq 'You are not authorized to access this page.'
    end
  end

  context 'when user has role guest' do
    let(:user) { guest }

    before { request }

    it { expect(response).to have_http_status(:forbidden) }

    it 'response contains proper error message' do
      expect(json_response['message']).to eq 'You are not authorized to access this page.'
    end
  end
end
