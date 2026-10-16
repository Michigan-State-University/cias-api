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

          context 'when user wants to set timout preferences' do
            let(:params) do
              {
                session: {
                  autofinish_enabled: true,
                  autofinish_delay: 10
                }
              }
            end

            it { expect(response).to have_http_status(:success) }
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

          context 'when user wants to set timout preferences' do
            let(:params) do
              {
                session: {
                  autofinish_enabled: true,
                  autofinish_delay: 'ten'
                }
              }
            end

            it {
              request
              expect(response).to have_http_status(:unprocessable_content)
            }
          end

          context 'when user wants to set timeout but without pass a delay' do
            let(:params) do
              {
                session: {
                  autofinish_enabled: true,
                  autofinish_delay: nil
                }
              }
            end

            it {
              request
              expect(response).to have_http_status(:unprocessable_content)
            }
          end

          context 'when user tries to set sms_code for Classic Session Type' do
            let(:params) do
              {
                session: {
                  sms_codes_attributes: [{ sms_code: 'SMS_CODE' }]
                }
              }
            end

            it {
              request
              expect(response).to have_http_status(:unprocessable_content)
            }
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

          context 'when user tries to set sms_code for CatMH Session type' do
            let(:params) do
              {
                session: {
                  sms_codes_attributes: [{ sms_code: 'SMS_CODE' }]
                }
              }
            end

            it {
              request
              expect(response).to have_http_status(:unprocessable_content)
            }
          end
        end

        context 'Session::Sms' do
          before { request }

          let(:session) { Session.create(name: 'SmsSession', intervention: intervention, type: 'Session::Sms') }
          let(:params) do
            {
              session: {
                name: 'Sms',
                sms_codes_attributes: [{ sms_code: 'SMS_CODE' }]
              }
            }
          end

          it 'updated values are proper' do
            expect(json_response['data']['attributes']).to include('name' => 'Sms')
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

  context 'formulas with branching targets' do
    let(:target_session) { create(:session, intervention: intervention) }
    let(:formulas) do
      [
        {
          'payload' => 'var1',
          'patterns' => [
            { 'match' => '=1', 'target' => [{ 'id' => target_session.id, 'probability' => '100', 'type' => 'Session' }] }
          ]
        }
      ]
    end
    let(:params) { { session: { formulas: formulas } } }
    let(:request) do
      patch v1_intervention_session_path(intervention_id: intervention.id, id: session.id), params: params, headers: headers, as: :json
    end

    before { request }

    it { expect(response).to have_http_status(:ok) }

    it 'returns target in the response' do
      expect(json_response['data']['attributes']['formulas']).to eq formulas
    end

    it 'persists target in the database' do
      expect(session.reload.formulas).to eq formulas
    end
  end

  context 'sms codes' do
    let(:session) { Session.create(name: 'SmsSession', intervention: intervention, type: 'Session::Sms') }
    let(:params) { { session: { sms_codes_attributes: [{ sms_code: 'FIRST_CODE' }, { sms_code: 'SECOND_CODE' }] } } }
    let(:request) do
      patch v1_intervention_session_path(intervention_id: intervention.id, id: session.id), params: params, headers: headers, as: :json
    end

    before { request }

    it { expect(response).to have_http_status(:ok) }

    it 'persists every sms code' do
      expect(session.reload.sms_codes.pluck(:sms_code)).to include('FIRST_CODE', 'SECOND_CODE')
    end

    context 'when existing sms code is updated' do
      let(:sms_code) { SmsCode.create!(session: session, sms_code: 'OLD_CODE') }
      let(:params) { { session: { sms_codes_attributes: [{ id: sms_code.id, sms_code: 'NEW_CODE' }] } } }

      it 'updates it' do
        expect(sms_code.reload.sms_code).to eq 'NEW_CODE'
      end
    end
  end

  it_behaves_like 'collaboration mode - only one editor at the same time'
end
