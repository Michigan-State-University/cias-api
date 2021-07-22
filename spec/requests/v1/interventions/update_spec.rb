# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/interventions', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:user_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant researcher guest]) }
  let(:guest) { create(:user, :guest) }
  let(:user) { admin }
  let(:headers) { user.create_new_auth_token }

  let(:params) do
    {
      intervention: {
        name: 'New Intervention',
        status: 'published'
      }
    }
  end

  let(:intervention_user) { admin }
  let!(:intervention) { create(:intervention, name: 'Old Intervention', user: intervention_user, status: 'draft') }
  let(:intervention_id) { intervention.id }
  let(:request) { patch v1_intervention_path(intervention_id), params: params, headers: headers }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:user_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant researcher guest]) }
  let(:guest) { create(:user, :guest) }
  let(:user) { admin }

  let_it_be(:language) { create(:google_language) }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { patch v1_intervention_path(intervention_id) }

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
      it { expect(response).to have_http_status(:ok) }

      it 'response contains proper attributes' do
        expect(json_response['data']['attributes']).to include(
          'name' => 'New Intervention',
          'status' => 'published',
          'shared_to' => 'anyone'
        )
      end

      it 'updates a intervention object' do
        expect(intervention.reload.attributes).to include(
          'name' => 'New Intervention',
          'status' => 'published',
          'shared_to' => 'anyone'
        )
      end

      context 'change language' do
        let(:params) do
          {
            intervention: {
              google_language_id: language.id
            }
          }
        end

        it 'update a intervention object' do
          expect(intervention.reload.attributes).to include(
            'google_language_id' => language.id
          )
        end

        it 'return correct data' do
          expect(json_response['data']['attributes']).to include(
            'language_name' => 'French',
            'language_code' => 'fr'
          )
        end
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

      it 'does not update a intervention object' do
        expect(intervention.reload.attributes).to include(
          'name' => 'Old Intervention',
          'status' => 'draft',
          'shared_to' => 'anyone'
        )
      end
    end
  end

  context 'when one of the roles is researcher' do
    shared_examples 'permitted user' do
      context 'intervention does not belong to him' do
        it { expect(response).to have_http_status(:not_found) }
      end

      context 'intervention belongs to him' do
        let(:intervention_user) { user }

        context 'when params are VALID' do
          it { expect(response).to have_http_status(:ok) }

          it 'response contains proper attributes' do
            expect(json_response['data']['attributes']).to include(
              'name' => 'New Intervention',
              'status' => 'published',
              'shared_to' => 'anyone'
            )
          end

          it 'updates a intervention object' do
            expect(intervention.reload.attributes).to include(
              'name' => 'New Intervention',
              'status' => 'published',
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

          it 'does not update a intervention object' do
            expect(intervention.reload.attributes).to include(
              'name' => 'Old Intervention',
              'status' => 'draft',
              'shared_to' => 'anyone'
            )
          end
        end
      end
    end

    context 'user is researcher' do
      let(:user) { researcher }

      before { request }

      it_behaves_like 'permitted user'
    end

    context 'user has multiple roles' do
      let(:user) { user_with_multiple_roles }

      before { request }

      it_behaves_like 'permitted user'
    end
  end

  context 'when user has role participant' do
    let(:user) { participant }

    before { request }

    it { expect(response).to have_http_status(:forbidden) }
  end

  context 'when user has role guest' do
    let(:user) { guest }

    before { patch v1_intervention_path(intervention_id), params: params, headers: headers }

    it { expect(response).to have_http_status(:forbidden) }
  end
end
