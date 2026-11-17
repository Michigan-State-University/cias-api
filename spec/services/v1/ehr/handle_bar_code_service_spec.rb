# frozen_string_literal: true

require 'webmock/rspec'

RSpec.describe V1::Ehr::HandleBarCodeService do
  include_context 'with barcode settings configured'

  describe '.call' do
    subject { described_class.call(user, params) }

    let(:user) { create(:user, :confirmed, :guest) }
    let(:params) { { barcode: barcode } }
    let(:barcode) { '<PtID>Z394</PtID><PtDAT>54348</PtDAT><UID> ' }
    let(:patient_id) { 'Z394' }
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

    before do
      allow_any_instance_of(Api::EpicOnFhir::PatientSearch).to receive(:call).and_return(epic_response)
    end

    context 'when patient is found successfully' do
      it 'creates a new HfhsPatientDetail record' do
        expect { subject }.to change(HfhsPatientDetail, :count).by(1)
      end

      it 'returns HfhsPatientDetail instance' do
        expect(subject).to be_a(HfhsPatientDetail)
      end

      it 'sets pending to true' do
        result = subject
        expect(result.pending).to be true
      end

      it 'records the scanning user as the owner of the draft' do
        expect(subject.drafted_by).to eq(user)
      end

      it 'stores the Epic patient id encrypted' do
        result = subject
        expect(result.epic_id).to eq('test-patient-id')
        expect(result.epic_id_ciphertext).to be_present
        expect(result.epic_id_ciphertext).not_to include('test-patient-id')
      end

      it 'schedules the expiry of the draft' do
        expect { subject }.to have_enqueued_job(Ehr::ClearAbandonedPatientDetailsJob).
          at(a_value_within(1.minute).of(Ehr::ClearAbandonedPatientDetailsJob::RETENTION_PERIOD.from_now + 1.hour))
      end

      it 'extracts and stores patient data correctly' do
        result = subject
        expect(result.patient_id).to eq('89010892')
        expect(result.first_name).to eq('John')
        expect(result.last_name).to eq('Doe')
        expect(result.dob).to eq(Date.parse('1980-01-01'))
        expect(result.sex).to eq('M')
        expect(result.zip_code).to eq('12345')
        expect(result.phone_type).to eq('mobile')
        expect(result.phone_number).to eq('+1234567890')
      end
    end

    describe 'phone selection' do
      def telecom(entries)
        epic_response[:entry][0][:resource][:telecom] = entries
      end

      it 'prefers a mobile number over a better-ranked home one' do
        telecom([{ system: 'phone', use: 'home', value: '111', rank: 1 },
                 { system: 'email', use: 'mobile', value: 'a@b.c' },
                 { system: 'phone', use: 'mobile', value: '222', rank: 2 }])
        expect(subject).to have_attributes(phone_number: '222', phone_type: 'mobile')
      end

      it 'falls back to the best-ranked phone when there is no mobile' do
        telecom([{ system: 'email', value: 'a@b.c' },
                 { system: 'phone', use: 'work', value: '333', rank: 2 },
                 { system: 'phone', use: 'home', value: '111', rank: 1 }])
        expect(subject).to have_attributes(phone_number: '111', phone_type: 'home')
      end

      it 'keeps the number but no type when the use is not one CIAS knows' do
        telecom([{ system: 'phone', use: 'temp', value: '444' }])
        expect(subject).to have_attributes(phone_number: '444', phone_type: nil)
      end

      it 'stores no phone when Epic has none' do
        telecom([{ system: 'email', value: 'a@b.c' }])
        expect(subject).to have_attributes(phone_number: nil, phone_type: nil)
      end
    end

    context 'when a confirmed record for the same patient already exists' do
      let(:other_user) { create(:user, :confirmed, :guest) }
      let!(:existing_patient) do
        create(:hfhs_patient_detail,
               patient_id: '89010892',
               first_name: 'Robert',
               last_name: 'Doe',
               dob: Date.parse('1980-01-01'),
               sex: 'M',
               zip_code: '11111',
               phone_type: 'home',
               phone_number: '+1111111111',
               pending: false)
      end

      before { other_user.update!(hfhs_patient_detail: existing_patient) }

      it 'creates a separate draft' do
        expect { subject }.to change(HfhsPatientDetail, :count).by(1)
        expect(subject.id).not_to eq(existing_patient.id)
      end

      it 'leaves the existing record untouched' do
        expect { subject }.not_to(change { existing_patient.reload.attributes })
        expect(other_user.reload.hfhs_patient_detail).to eq(existing_patient)
      end
    end

    context 'when a pending draft for the same patient already exists' do
      let!(:existing_draft) do
        create(:hfhs_patient_detail, patient_id: '89010892', pending: true, drafted_by: create(:user, :confirmed, :guest))
      end

      it 'creates a new draft owned by the scanning user' do
        expect { subject }.to change(HfhsPatientDetail, :count).by(1)
        expect(subject.id).not_to eq(existing_draft.id)
        expect(subject.drafted_by).to eq(user)
      end

      it 'does not touch the other draft' do
        expect { subject }.not_to(change { existing_draft.reload.attributes })
      end
    end

    context 'when multiple patients are found' do
      let(:epic_response_multiple) do
        epic_response.merge(total: 2)
      end

      before do
        allow_any_instance_of(Api::EpicOnFhir::PatientSearch).to receive(:call).and_return(epic_response_multiple)
      end

      it 'answers like no match at all' do
        expect { subject }.to raise_error(EpicOnFhir::NotFound, I18n.t('epic_on_fhir.error.patient.not_found'))
      end

      it 'does not create any records' do
        expect do
          subject
        rescue StandardError
          nil
        end.not_to change(HfhsPatientDetail, :count)
      end
    end

    # Stubbed at the HTTP layer: PatientSearch turns a zero-result bundle into
    # EpicOnFhir::NotFound before this service sees it.
    context 'when no patients are found' do
      before do
        allow_any_instance_of(Api::EpicOnFhir::PatientSearch).to receive(:call).and_call_original
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('EPIC_ON_FHIR_BARCODE_IDENTIFIER_SYSTEM', nil).and_return('urn:oid:1.2.3')
        stub_request(:get, ENV.fetch('EPIC_ON_FHIR_PATIENT_ENDPOINT').chomp('/'))
          .with(query: { '_format' => 'json', 'identifier' => 'urn:oid:1.2.3|Z394' })
          .to_return(status: 200, body: epic_response.merge(total: 0, entry: []).to_json)
      end

      it 'raises EpicOnFhir::NotFound' do
        expect { subject }.to raise_error(EpicOnFhir::NotFound)
      end

      it 'does not create any records' do
        expect do
          subject
        rescue StandardError
          nil
        end.not_to change(HfhsPatientDetail, :count)
      end
    end

    context 'when patient ID cannot be extracted from EPIC response' do
      let(:epic_response_no_system_id) do
        response = epic_response.deep_dup
        response[:entry][0][:resource][:identifier] = [
          {
            type: { text: 'OTHER_SYSTEM' },
            value: 'other-value'
          }
        ]
        response
      end

      before do
        allow_any_instance_of(Api::EpicOnFhir::PatientSearch).to receive(:call).and_return(epic_response_no_system_id)
      end

      it 'raises PatientIdentifierMissingError' do
        expect { subject }.to raise_error(Ehr::PatientIdentifierMissingError)
      end

      it 'does not create any records' do
        expect do
          subject
        rescue StandardError
          nil
        end.not_to change(HfhsPatientDetail, :count)
      end
    end

    context 'when FindPatientByIdService raises an error' do
      before do
        allow_any_instance_of(Api::EpicOnFhir::PatientSearch).to receive(:call).and_raise(StandardError, 'API Error')
      end

      it 'propagates the error' do
        expect { subject }.to raise_error(StandardError, 'API Error')
      end

      it 'does not create any records' do
        expect do
          subject
        rescue StandardError
          nil
        end.not_to change(HfhsPatientDetail, :count)
      end
    end
  end

  describe '#call' do
    subject { described_class.new(user, params).call }

    let(:user) { create(:user, :confirmed, :guest) }
    let(:params) { { barcode: '<PtID>Z394</PtID><PtDAT>54348</PtDAT><UID> ' } }
    let(:patient_id) { 'Z394' }
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
                  type: { text: ENV.fetch('EPIC_ON_FHIR_SYSTEM_IDENTIFIER', 'KEY_TO_IDENTIFYING_SPECIFIC_SYSTEM') },
                  value: '89010892'
                }
              ],
              name: [
                {
                  given: ['Jane'],
                  family: 'Smith'
                }
              ],
              birthDate: '1990-05-15',
              gender: 'female',
              address: [
                {
                  use: 'home',
                  postalCode: '54321'
                }
              ],
              telecom: [
                {
                  system: 'phone',
                  use: 'work',
                  value: '+9876543210'
                }
              ]
            }
          }
        ]
      }
    end

    before do
      allow_any_instance_of(Api::EpicOnFhir::PatientSearch).to receive(:call).and_return(epic_response)
    end

    context 'when called as instance method' do
      it 'creates HfhsPatientDetail with correct data' do
        result = subject
        expect(result).to be_a(HfhsPatientDetail)
        expect(result.patient_id).to eq('89010892')
        expect(result.first_name).to eq('Jane')
        expect(result.last_name).to eq('Smith')
        expect(result.dob).to eq(Date.parse('1990-05-15'))
        expect(result.sex).to eq('F')
        expect(result.zip_code).to eq('54321')
        expect(result.phone_type).to eq('work')
        expect(result.phone_number).to eq('+9876543210')
        expect(result.pending).to be true
      end
    end
  end

  describe 'service initialization' do
    let(:params) { { barcode: '<PtID>Z394</PtID>' } }
    let(:user) { build(:user) }
    let(:service) { described_class.new(user, params) }

    it 'stores params' do
      expect(service.params).to eq(params)
    end

    it 'stores the scanning user' do
      expect(service.user).to eq(user)
    end

    it 'has accessible params' do
      expect(service).to respond_to(:params)
    end
  end

  describe 'private methods' do
    let(:service) { described_class.new(build(:user), {}) }
    let(:epic_response) do
      {
        entry: [
          {
            resource: {
              identifier: [
                {
                  type: { text: 'OTHER_SYSTEM' },
                  value: 'other-value'
                },
                {
                  type: { text: ENV.fetch('EPIC_ON_FHIR_SYSTEM_IDENTIFIER', 'KEY_TO_IDENTIFYING_SPECIFIC_SYSTEM') },
                  value: 'test-patient-id-123'
                }
              ]
            }
          }
        ]
      }
    end

    describe '#hfhs_patient_id' do
      it 'extracts patient ID from EPIC response based on system identifier' do
        result = service.send(:hfhs_patient_id, epic_response)
        expect(result).to eq('test-patient-id-123')
      end

      context 'when system identifier is not found' do
        let(:epic_response_no_match) do
          {
            entry: [
              {
                resource: {
                  identifier: [
                    {
                      type: { text: 'OTHER_SYSTEM' },
                      value: 'other-value'
                    }
                  ]
                }
              }
            ]
          }
        end

        it 'raises PatientIdentifierMissingError' do
          expect { service.send(:hfhs_patient_id, epic_response_no_match) }.
            to raise_error(Ehr::PatientIdentifierMissingError)
        end
      end

      context 'when identifiers array is empty' do
        let(:epic_response_empty_identifiers) do
          {
            entry: [
              {
                resource: {
                  identifier: []
                }
              }
            ]
          }
        end

        it 'raises PatientIdentifierMissingError' do
          expect { service.send(:hfhs_patient_id, epic_response_empty_identifiers) }.
            to raise_error(Ehr::PatientIdentifierMissingError)
        end
      end
    end
  end
end
