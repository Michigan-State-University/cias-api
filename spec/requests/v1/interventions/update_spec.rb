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
  let!(:intervention) do
    create(:intervention, name: 'Old Intervention', user: intervention_user, status: 'draft', cat_mh_application_id: 'application_id',
                          cat_mh_organization_id: 'organization_id', cat_mh_pool: 10)
  end
  let!(:short_link) { create(:short_link, linkable: intervention) }
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

      context 'short links' do
        context 'when user change other params' do
          it 'short link stay without any change' do
            expect(intervention.reload.short_links.first.id).to eq short_link.id
            expect(intervention.reload.short_links.count).to eq 1
          end
        end

        context 'when organization id will change' do
          let(:params) do
            {
              intervention: {
                organization_id: create(:organization).id
              }
            }
          end

          it 'clear all short links belongs to the intervention' do
            expect(intervention.reload.short_links.count).to eq 0
          end
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

  context 'when intervention is incorrect' do
    let!(:intervention) { create(:intervention, name: 'Old Intervention', user: intervention_user, status: 'draft', license_type: 'limited') }
    let!(:session) { create(:cat_mh_session, :with_cat_mh_info, :with_test_type_and_variables, intervention: intervention) }

    before { request }

    it 'return correct status' do
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'return correct error message' do
      expect(json_response['message']).to eql('Validation failed: Intervention should have all cat mh settings before publishing. ERROR_FLAG:CatMhWrongSettings') # rubocop:disable Layout/LineLength
    end
  end

  context 'when intervention is published' do
    let!(:intervention) do
      create(:intervention, name: 'Old Intervention', user: intervention_user, status: 'published', cat_mh_application_id: 'application_id',
                            cat_mh_organization_id: 'organization_id', cat_mh_pool: 10)
    end

    let(:params) do
      {
        intervention: {
          name: 'New name',
          cat_mh_pool: 100
        }
      }
    end

    before { request }

    it 'response contains proper attributes' do
      expect(json_response['data']['attributes']).to include(
        'name' => 'Old Intervention',
        'cat_mh_pool' => 100
      )
    end

    it 'updates a intervention object' do
      expect(intervention.reload.attributes).to include(
        'name' => 'Old Intervention',
        'cat_mh_pool' => 100
      )
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

          context 'quick_exit - researcher is able to set this option if wants to give an option to
                    a participant to a quick exit from filling and clear the footprint from history' do
            let(:params) do
              {
                intervention: {
                  quick_exit: true
                }
              }
            end

            it 'updates a intervention object' do
              expect(intervention.reload.attributes).to include('quick_exit' => true)
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

  context 'researcher who is a collaborator' do
    let(:user) { create(:user, :researcher, :confirmed) }
    let!(:collaborator) { create(:collaborator, intervention: intervention, user: user, view: true, edit: false) }

    before { request }

    it { expect(response).to have_http_status(:forbidden) }
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

  context 'live_chat' do
    context 'when intervention closed/archived and live chat enabled' do
      let(:user) { create(:user, :admin, :confirmed) }
      let(:intervention) { create(:intervention, user: user, status: 'closed') }
      let(:headers) { user.create_new_auth_token }
      let(:params) do
        {
          intervention: {
            live_chat_enabled: true
          }
        }
      end

      before { request }

      it 'returns correct status code (Unprocessable entity)' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'sends validation error message' do
        expect(json_response['message']).to eq 'Validation failed: Live chat cannot be turned on for closed or archived interventions.'
      end
    end

    context 'when intervention draft or active' do
      let(:user) { create(:user, :admin, :confirmed) }
      let(:intervention) { create(:intervention, user: user, status: 'draft') }
      let(:headers) { user.create_new_auth_token }
      let(:params) do
        {
          intervention: {
            live_chat_enabled: true
          }
        }
      end

      before { request }

      it 'returns correct status code (OK)' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns live chat setting' do
        expect(json_response['data']['attributes']).to include('live_chat_enabled' => true)
      end
    end
  end
end
