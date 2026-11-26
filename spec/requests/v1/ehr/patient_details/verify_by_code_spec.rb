# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

# /v1/ehr/verify_by_code is the site-neutral path of the same action; /v1/henry_ford/verify_by_code stays for one release.
RSpec.describe 'POST /v1/ehr/verify_by_code and POST /v1/henry_ford/verify_by_code', type: :request do
  include_context 'with barcode settings configured'

  %w[/v1/ehr/verify_by_code /v1/henry_ford/verify_by_code].each do |path|
    context "via #{path}" do
      let(:user) { create(:user, :confirmed, :participant) }
      let(:headers) { user.create_new_auth_token }
      let(:valid_barcode) { '<PtID>Z394</PtID><PtDAT>54348</PtDAT><UID> ' }
      let(:hfhs_access) { true }
      let(:ehr_session) { create(:session, intervention: create(:intervention, hfhs_access: hfhs_access)) }
      let(:with_initial_question) { true }
      let(:with_user_session) { true }
      let(:params) do
        {
          hfhs_patient_data: {
            barcode: valid_barcode
          },
          session_id: ehr_session.id
        }
      end

      let(:epic_response) do
        {
          resourceType: 'Bundle',
          type: 'searchset',
          total: 1,
          entry: [
            {
              resource: {
                resourceType: 'Patient',
                id: 'test-patient-id',
                identifier: [
                  {
                    type: { text: 'OTHER_SYSTEM' },
                    value: 'other-value'
                  },
                  {
                    type: { text: ENV.fetch('EPIC_ON_FHIR_SYSTEM_IDENTIFIER', 'KEY_TO_IDENTIFYING_SPECIFIC_SYSTEM') },
                    value: '89010892'
                  }
                ],
                name: [
                  {
                    given: ['John'],
                    family: 'Doe'
                  }
                ],
                birthDate: '1980-01-01',
                gender: 'male',
                address: [
                  {
                    use: 'home',
                    postalCode: '12345'
                  }
                ],
                telecom: [
                  {
                    system: 'phone',
                    use: 'mobile',
                    value: '+1234567890'
                  }
                ]
              }
            }
          ]
        }
      end
      let(:request) { post path, params: params, headers: headers }

      before do
        create(:question_henry_ford_initial_screen, question_group: create(:question_group, session: ehr_session)) if with_initial_question
        create(:user_session, user: user, session: ehr_session) if with_user_session
      end

      context 'when epic returns one patient' do
        before do
          allow_any_instance_of(Api::EpicOnFhir::PatientSearch).to receive(:call).and_return(epic_response)
        end

        context 'when auth' do
          before do
            request
          end

          context 'is invalid' do
            let(:request) { post path, params: params }

            it_behaves_like 'unauthorized user'
          end

          context 'is valid' do
            it_behaves_like 'authorized user'
          end
        end

        context 'when user is registered participant' do
          before do
            request
          end

          it 'returns correct status' do
            expect(response).to have_http_status(:ok)
          end

          it 'returns serialized HfhsPatientDetail' do
            json_response = response.parsed_body
            expect(json_response).to have_key('data')
            expect(json_response['data']).to have_key('id')
            expect(json_response['data']).to have_key('type')
            expect(json_response['data']['type']).to eq('hfhs_patient_detail_anonymized')
          end

          it 'creates patient detail record with correct data' do
            json_response = response.parsed_body
            patient_detail = HfhsPatientDetail.find(json_response['data']['id'])

            expect(patient_detail.patient_id).to eq('89010892')
            expect(patient_detail.first_name).to eq('John')
            expect(patient_detail.last_name).to eq('Doe')
            expect(patient_detail.dob).to eq(Date.parse('1980-01-01'))
            expect(patient_detail.sex).to eq('M')
            expect(patient_detail.zip_code).to eq('12345')
            expect(patient_detail.phone_type).to eq('mobile')
            expect(patient_detail.phone_number).to eq('+1234567890')
            expect(patient_detail.pending).to be true
          end
        end

        context 'when user is guest' do
          let(:user) { create(:user, :confirmed, :guest) }

          before do
            request
          end

          it 'returns correct status' do
            expect(response).to have_http_status(:ok)
          end

          it 'creates patient detail record' do
            json_response = response.parsed_body
            expect(json_response['data']['type']).to eq('hfhs_patient_detail_anonymized')
          end
        end

        context 'when barcode is invalid' do
          before do
            request
          end

          context 'when barcode is empty' do
            let(:params) do
              {
                hfhs_patient_data: {
                  barcode: ''
                },
                session_id: ehr_session.id
              }
            end

            it 'returns error status' do
              expect(response).to have_http_status(:unprocessable_content)
            end
          end

          context 'when barcode is nil' do
            let(:params) do
              {
                hfhs_patient_data: {
                  barcode: nil
                },
                session_id: ehr_session.id
              }
            end

            it 'returns error status' do
              expect(response).to have_http_status(:unprocessable_content)
            end
          end

          context 'when barcode format is invalid' do
            let(:params) do
              {
                hfhs_patient_data: {
                  barcode: 'invalid_barcode_format'
                },
                session_id: ehr_session.id
              }
            end

            it 'returns error status' do
              expect(response).to have_http_status(:unprocessable_content)
            end
          end

          context 'when patient ID is missing from barcode' do
            let(:params) do
              {
                hfhs_patient_data: {
                  barcode: '<PtDAT>54348</PtDAT><UID> '
                },
                session_id: ehr_session.id
              }
            end

            it 'returns error status' do
              expect(response).to have_http_status(:unprocessable_content)
            end
          end
        end

        context 'when patient already exists in database' do
          let!(:existing_patient) do
            create(:hfhs_patient_detail,
                   patient_id: '89010892',
                   first_name: 'John',
                   last_name: 'Doe',
                   dob: Date.parse('1980-01-01'),
                   sex: 'M',
                   zip_code: '12345',
                   phone_type: 'mobile',
                   phone_number: '+1234567890',
                   pending: false)
          end

          before do
            request
          end

          it 'returns correct status' do
            expect(response).to have_http_status(:ok)
          end

          it 'returns a new draft owned by the scanning user, not the existing record' do
            patient_detail = HfhsPatientDetail.find(response.parsed_body['data']['id'])

            expect(patient_detail.id).not_to eq(existing_patient.id)
            expect(patient_detail.pending).to be true
            expect(patient_detail.drafted_by).to eq(user)
          end

          it 'leaves the existing record confirmed and unchanged' do
            expect(HfhsPatientDetail.count).to eq(2)
            expect(existing_patient.reload.pending).to be false
            expect(existing_patient.drafted_by).to be_nil
          end
        end

        context 'when required parameters are missing' do
          before do
            request
          end

          context 'when hfhs_patient_data is missing' do
            let(:params) { {} }

            it 'returns error status' do
              expect(response).to have_http_status(:bad_request)
            end
          end

          context 'when barcode parameter is missing' do
            let(:params) do
              {
                hfhs_patient_data: {},
                session_id: ehr_session.id
              }
            end

            it 'returns error status' do
              expect(response).to have_http_status(:bad_request)
            end
          end
        end
      end

      # Answered exactly like zero matches, so a miss cannot be told apart from
      # a hit on several patients.
      context 'when Epic API returns multiple patients' do
        let(:epic_response_multiple) do
          epic_response.merge(total: 2)
        end

        before do
          allow_any_instance_of(Api::EpicOnFhir::PatientSearch).to receive(:call).and_return(epic_response_multiple)
          request
        end

        it 'returns not found with the same message as no match' do
          expect(response).to have_http_status(:not_found)
          expect(response.parsed_body['message']).to eq(I18n.t('epic_on_fhir.error.patient.not_found'))
          expect(HfhsPatientDetail.count).to eq(0)
        end
      end

      describe 'session scope' do
        before do
          allow_any_instance_of(Api::EpicOnFhir::PatientSearch).to receive(:call).and_return(epic_response)
          request
        end

        shared_examples 'a refused scan' do
          it 'returns forbidden with the translated message and looks nobody up' do
            expect(response).to have_http_status(:forbidden)
            expect(response.parsed_body['message']).to eq(I18n.t('ehr.error.session.not_allowed'))
            expect(HfhsPatientDetail.count).to eq(0)
          end
        end

        context 'when session_id is missing' do
          let(:params) { { hfhs_patient_data: { barcode: valid_barcode } } }

          it 'returns bad request' do
            expect(response).to have_http_status(:bad_request)
            expect(HfhsPatientDetail.count).to eq(0)
          end
        end

        context 'when the session does not exist' do
          let(:params) { { hfhs_patient_data: { barcode: valid_barcode }, session_id: SecureRandom.uuid } }

          it_behaves_like 'a refused scan'
        end

        context 'when the intervention has no HFHS access' do
          let(:hfhs_access) { false }

          it_behaves_like 'a refused scan'
        end

        context 'when the session has no Henry Ford initial question' do
          let(:with_initial_question) { false }

          it_behaves_like 'a refused scan'
        end

        context 'when the user is not answering the session' do
          let(:with_user_session) { false }

          it_behaves_like 'a refused scan'
        end
      end

      # Stubbed at the HTTP layer: a zero-result bundle is turned into
      # EpicOnFhir::NotFound by PatientSearch itself, so the client sees a 404.
      context 'when Epic API returns no patients' do
        before do
          allow(ENV).to receive(:fetch).and_call_original
          allow(ENV).to receive(:fetch).with('EPIC_ON_FHIR_BARCODE_IDENTIFIER_SYSTEM', nil).and_return('urn:oid:1.2.3')
          stub_request(:get, ENV.fetch('EPIC_ON_FHIR_PATIENT_ENDPOINT').chomp('/'))
            .with(query: { '_format' => 'json', 'identifier' => 'urn:oid:1.2.3|Z394' })
            .to_return(status: 200, body: epic_response.merge(total: 0, entry: []).to_json)
          request
        end

        it 'returns not found with the translated message' do
          expect(response).to have_http_status(:not_found)
          expect(response.parsed_body['message']).to eq(I18n.t('epic_on_fhir.error.patient.not_found'))
          expect(HfhsPatientDetail.count).to eq(0)
        end
      end

      context 'when the Epic patient has no identifier of the configured system' do
        before do
          epic_response[:entry][0][:resource][:identifier] = [{ type: { text: 'OTHER_SYSTEM' }, value: 'other-value' }]
          allow_any_instance_of(Api::EpicOnFhir::PatientSearch).to receive(:call).and_return(epic_response)
          request
        end

        it 'returns unprocessable entity with the translated message' do
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body['message']).to eq(I18n.t('ehr.error.patient.identifier_missing'))
          expect(HfhsPatientDetail.count).to eq(0)
        end
      end

      describe 'scan feature flag' do
        before do
          allow(Api::EpicOnFhir::PatientSearch).to receive(:call)
          allow(Api::EpicOnFhir::Authentication).to receive(:call)
          allow(Sentry).to receive(:capture_message)
          allow(Rails.logger).to receive(:error).and_call_original
        end

        shared_examples 'a scan refused before Epic' do
          it 'refuses like an unavailable session, with no Epic call, draft or expiry job' do
            expect { request }.not_to have_enqueued_job(Ehr::ClearAbandonedPatientDetailsJob)
            expect(response).to have_http_status(:forbidden)
            expect(response.parsed_body['message']).to eq(I18n.t('ehr.error.session.not_allowed'))
            expect(Api::EpicOnFhir::PatientSearch).not_to have_received(:call)
            expect(Api::EpicOnFhir::Authentication).not_to have_received(:call)
            expect(HfhsPatientDetail.count).to eq(0)
          end
        end

        [nil, '', '0', 'true'].each do |flag|
          context "when the flag is #{flag.inspect}" do
            include_context 'with environment variables', { 'EHR_BARCODE_SCAN_FEATURE_ENABLED' => flag }

            it_behaves_like 'a scan refused before Epic'

            it 'reports nothing: off is a normal state' do
              request

              expect(Sentry).not_to have_received(:capture_message)
            end
          end
        end

        # The flag is checked before the session lookup, so a request without session_id stays a silent 403
        # instead of a ParameterMissing 400 that ExceptionHandler reports to Sentry.
        context 'when the flag is off and the request has no session_id' do
          include_context 'with environment variables', { 'EHR_BARCODE_SCAN_FEATURE_ENABLED' => nil }

          let(:params) { { hfhs_patient_data: { barcode: valid_barcode } } }

          before { allow(Sentry).to receive(:capture_exception) }

          it 'refuses with the same 403 and reports nothing' do
            request

            expect(response).to have_http_status(:forbidden)
            expect(response.parsed_body['message']).to eq(I18n.t('ehr.error.session.not_allowed'))
            expect(Sentry).not_to have_received(:capture_message)
            expect(Sentry).not_to have_received(:capture_exception)
          end
        end

        { 'EHR_BARCODE_PATIENT_ID_PATTERN' => '', 'EPIC_ON_FHIR_BARCODE_IDENTIFIER_SYSTEM' => nil }.each do |setting, blank|
          context "when the flag is on and #{setting} is blank" do
            include_context 'with environment variables', { 'EHR_BARCODE_SCAN_FEATURE_ENABLED' => ' 1 ', setting => blank }

            let(:report) { "[Ehr::Settings] code scanning is on but required settings are blank: #{setting}" }

            it_behaves_like 'a scan refused before Epic'

            it 'reports the missing setting by name to Sentry and the log' do
              request

              expect(Sentry).to have_received(:capture_message).with(report).once
              expect(Rails.logger).to have_received(:error).with(report)
            end
          end
        end
      end

      # Not rescued into a 4xx: sentry-rails reports it, and every scan fails until the setting is fixed.
      context 'when a barcode setting is not a usable regular expression' do
        include_context 'with environment variables', { 'EHR_BARCODE_PATIENT_ID_PATTERN' => '[' }

        it 'raises the setting error without asking Epic' do
          allow(Api::EpicOnFhir::PatientSearch).to receive(:call)

          expect { request }.to raise_error(Ehr::Settings::InvalidSettingError, /EHR_BARCODE_PATIENT_ID_PATTERN/)
          expect(Api::EpicOnFhir::PatientSearch).not_to have_received(:call)
        end
      end

      context 'when the PtID carries FHIR search syntax' do
        let(:valid_barcode) { '<PtID>urn:oid:1.2.840.114350.1.13.338.3.7.5.737384.48|82000421</PtID>' }

        before do
          allow_any_instance_of(Api::EpicOnFhir::PatientSearch).to receive(:call).and_return(epic_response)
          request
        end

        it 'is rejected before Epic is asked' do
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body['message']).to eq(I18n.t('ehr.error.barcode.parsing_error'))
          expect(HfhsPatientDetail.count).to eq(0)
        end
      end
    end
  end
end
