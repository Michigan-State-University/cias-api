# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/interventions/:intervention_id/sessions/:id', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:admin_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }
  let(:user) { admin }
  let(:users) do
    {
      'admin' => admin,
      'admin_with_multiple_roles' => admin_with_multiple_roles
    }
  end
  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      session: {
        name: 'test1 params',
        days_after_date_variable_name: 'var1',
        cat_tests: %w[mdd ss],
        estimated_time: 10,
        multiple_fill: true
      }
    }
  end
  let(:request) { patch v1_intervention_session_path(intervention_id: intervention.id, id: session.id), params: params, headers: headers }

  context 'one or multiple roles' do
    shared_examples 'permitted user' do
      context 'when params' do
        context 'valid' do
          before do
            session.reload
            request
          end

          it { expect(response).to have_http_status(:success) }

          it 'updated values are proper' do
            expect(json_response['data']['attributes']).to include('name' => 'test1 params',
                                                                   'days_after_date_variable_name' => 'var1',
                                                                   'estimated_time' => 10, 'multiple_fill' => true)
          end
        end

        context 'invalid' do
          context 'params' do
            before do
              invalid_params = { session: {} }
              session.reload
              patch v1_intervention_session_path(intervention_id: intervention.id, id: session.id),
                    params: invalid_params, headers: headers
            end

            it { expect(response).to have_http_status(:bad_request) }
          end
        end

        context 'Session::CatMh' do
          before { request }

          let(:session) { Session.create(name: 'CatSession', intervention: intervention, type: 'Session::CatMh') }
          let(:cat_mh_test_type) { create(:cat_mh_test_type) }
          let(:cat_mh_test_type_id) { cat_mh_test_type.id }
          let(:params) do
            {
              session: {
                name: 'Cat-Mh',
                days_after_date_variable_name: 'var1',
                cat_tests: [cat_mh_test_type_id]
              }
            }
          end

          it 'updated values are proper' do
            expect(json_response['data']['attributes']).to include('name' => 'Cat-Mh',
                                                                   'days_after_date_variable_name' => 'var1')
          end

          it 'added test to session' do
            expect(json_response['data']['relationships']).to include('cat_mh_test_types' => {
                                                                        'data' => [
                                                                          {
                                                                            'id' => cat_mh_test_type_id.to_s,
                                                                            'type' => 'test_type'
                                                                          }
                                                                        ]
                                                                      })
          end
        end
      end
    end

    %w[admin admin_with_multiple_roles].each do |role|
      let(:user) { users[role] }

      context 'when auth' do
        context 'is invalid' do
          let(:request) { patch v1_intervention_session_path(intervention_id: intervention.id, id: session.id) }

          it_behaves_like 'unauthorized user'
        end

        context 'is valid' do
          it_behaves_like 'authorized user'
        end
      end

      it_behaves_like 'permitted user'
    end
  end

  context 'empty formulas' do
    let(:params) do
      {
        session: {
          name: 'test1 params',
          days_after_date_variable_name: 'var1',
          body: {
            payload: 1,
            target: '',
            variable: '1'
          },
          formulas: []
        }
      }
    end

    it 'lets users assign empty array of formulas' do
      request
      expect(json_response['data']['attributes']['formulas']).to eq []
    end
  end
end
