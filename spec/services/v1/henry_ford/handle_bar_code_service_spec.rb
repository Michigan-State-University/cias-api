# frozen_string_literal: true

RSpec.describe V1::HenryFord::HandleBarCodeService do
  describe '.call' do
    subject { described_class.call(params) }

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

      it 'extracts and stores patient data correctly' do
        result = subject
        expect(result.patient_id).to eq('89010892')
        expect(result.first_name).to eq('John')
        expect(result.last_name).to eq('Doe')
        expect(result.dob).to eq(Date.parse('1980-01-01'))
        expect(result.sex).to eq('male')
        expect(result.zip_code).to eq('12345')
        expect(result.phone_type).to eq('mobile')
        expect(result.phone_number).to eq('+1234567890')
      end
    end

    context 'when patient already exists' do
      let!(:existing_patient) do
        create(:hfhs_patient_detail,
               patient_id: '89010892',
               first_name: 'John',
               last_name: 'Doe',
               dob: Date.parse('1980-01-01'),
               sex: 'male',
               zip_code: '12345',
               phone_type: 'mobile',
               phone_number: '+1234567890',
               pending: false)
      end

      it 'does not create a new record' do
        expect { subject }.not_to change(HfhsPatientDetail, :count)
      end

      it 'updates existing record to pending: true' do
        result = subject
        expect(result.id).to eq(existing_patient.id)
        expect(result.pending).to be true
      end

      it 'returns the existing record' do
        result = subject
        expect(result).to eq(existing_patient.reload)
      end
    end

    context 'when multiple patients are found' do
      let(:epic_response_multiple) do
        epic_response.merge(total: 2)
      end

      before do
        allow_any_instance_of(Api::EpicOnFhir::PatientSearch).to receive(:call).and_return(epic_response_multiple)
      end

      it 'raises MultiplePatientsFoundError' do
        expect { subject }.to raise_error(HenryFord::MultiplePatientsFoundError)
      end

      it 'does not create any records' do
        expect do
          subject
        rescue StandardError
          nil
        end.not_to change(HfhsPatientDetail, :count)
      end
    end

    context 'when no patients are found' do
      let(:epic_response_empty) do
        epic_response.merge(total: 0)
      end

      before do
        allow_any_instance_of(Api::EpicOnFhir::PatientSearch).to receive(:call).and_return(epic_response_empty)
      end

      it 'raises MultiplePatientsFoundError' do
        expect { subject }.to raise_error(HenryFord::MultiplePatientsFoundError)
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

      it 'creates record with nil patient_id' do
        expect { subject }.to raise_error(ActiveRecord::RecordInvalid, /Patient can't be blank/)
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
    subject { described_class.new(params).call }

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
        expect(result.sex).to eq('female')
        expect(result.zip_code).to eq('54321')
        expect(result.phone_type).to eq('work')
        expect(result.phone_number).to eq('+9876543210')
        expect(result.pending).to be true
      end
    end
  end

  describe 'service initialization' do
    let(:params) { { barcode: '<PtID>Z394</PtID>' } }
    let(:service) { described_class.new(params) }

    it 'stores params' do
      expect(service.params).to eq(params)
    end

    it 'has accessible params' do
      expect(service).to respond_to(:params)
    end
  end

  describe 'private methods' do
    let(:service) { described_class.new({}) }
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

        it 'returns nil' do
          result = service.send(:hfhs_patient_id, epic_response_no_match)
          expect(result).to be_nil
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

        it 'returns nil' do
          result = service.send(:hfhs_patient_id, epic_response_empty_identifiers)
          expect(result).to be_nil
        end
      end
    end
  end
end
