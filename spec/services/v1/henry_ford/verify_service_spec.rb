# frozen_string_literal: true

RSpec.describe V1::HenryFord::VerifyService do
  subject { described_class.new(user, params, session.id).call }

  let(:user) { create(:user, :participant, :confirmed) }
  let(:intervention) { create(:intervention) }
  let!(:location) do
    create(:intervention_location, intervention: intervention,
                                   clinic_location: create(:clinic_location,
                                                           name: 'brukowa',
                                                           department: 'HTD',
                                                           external_id: 'externalID',
                                                           external_name: 'brukowa'))
  end
  let!(:session) { create(:session, intervention: intervention) }
  let(:params) do
    {
      first_name: user.first_name,
      last_name: user.last_name,
      dob: 40.years.ago.strftime('%Y-%m-%d'),
      sex: 'M',
      zip_code: Faker::Address.zip,
      phone_number: Faker::PhoneNumber.cell_phone,
      phone_type: :home
    }.deep_transform_keys(&:to_s)
  end

  context 'when patient and appointments were returned' do
    before do
      allow_any_instance_of(Date).to receive(:future?).and_return(true)

      allow_any_instance_of(Api::EpicOnFhir::PatientVerification).to receive(:call).and_return(
        JSON.parse(File.read('spec/fixtures/integrations/henry_ford/patient_resource.json')).deep_symbolize_keys
      )
      allow_any_instance_of(Api::EpicOnFhir::Appointments).to receive(:call).and_return(
        JSON.parse(File.read('spec/fixtures/integrations/henry_ford/appointments.json')).deep_symbolize_keys
      )
    end

    it 'create a new record' do
      expect { subject }.to change(HfhsPatientDetail, :count).by(1)
    end

    it 'return patient detail' do
      expect(subject.class).to be(HfhsPatientDetail)
    end

    it 'assign expected appointment id and patient_id' do
      subject
      expect(user.hfhs_patient_detail.visit_id).to eql('_externalID_10022118420')
      expect(user.hfhs_patient_detail.patient_id).to eql('89010892')
    end
  end

  context 'when patient doesn\'t have appointment in the future' do
    before do
      allow_any_instance_of(Api::EpicOnFhir::PatientVerification).to receive(:call).and_return(
        JSON.parse(File.read('spec/fixtures/integrations/henry_ford/patient_resource.json')).deep_symbolize_keys
      )
      allow_any_instance_of(Api::EpicOnFhir::Appointments).to receive(:call).and_return(
        JSON.parse(File.read('spec/fixtures/integrations/henry_ford/appointments.json')).deep_symbolize_keys
      )
    end

    it 'raise exception' do
      expect { subject }.to raise_error(EpicOnFhir::NotFound)
    end
  end

  context 'when hfhs_patient_detail_id is provided' do
    let!(:existing_patient_detail) do
      create(:hfhs_patient_detail,
             patient_id: '89010892',
             first_name: 'John',
             last_name: 'Doe',
             dob: Date.parse('1980-01-01'),
             sex: 'male',
             zip_code: '12345',
             phone_type: 'mobile',
             phone_number: '+1234567890',
             epic_id: 'test-epic-id-123',
             pending: true)
    end

    let(:params) do
      {
        hfhs_patient_detail_id: existing_patient_detail.id
      }
    end

    before do
      allow_any_instance_of(Date).to receive(:future?).and_return(true)

      allow_any_instance_of(Api::EpicOnFhir::PatientVerification).to receive(:call).and_return(
        JSON.parse(File.read('spec/fixtures/integrations/henry_ford/patient_resource.json')).deep_symbolize_keys
      )
      allow_any_instance_of(Api::EpicOnFhir::Appointments).to receive(:call).and_return(
        JSON.parse(File.read('spec/fixtures/integrations/henry_ford/appointments.json')).deep_symbolize_keys
      )
    end

    it 'does not create a new record' do
      expect { subject }.not_to change(HfhsPatientDetail, :count)
    end

    it 'returns the existing patient detail' do
      expect(subject).to eq(existing_patient_detail.reload)
    end

    it 'sets pending to false' do
      subject
      expect(existing_patient_detail.reload.pending).to be false
    end

    it 'updates visit_id' do
      subject
      expect(existing_patient_detail.reload.visit_id).to eql('_externalID_10022118420')
    end

    it 'does not call patient verification API' do
      expect_any_instance_of(Api::EpicOnFhir::PatientVerification).not_to receive(:call)
      subject
    end

    it 'assigns patient details to user' do
      subject
      expect(user.reload.hfhs_patient_detail).to eq(existing_patient_detail)
    end
  end

  context 'when hfhs_patient_detail_id is provided but record not found' do
    let(:params) do
      {
        hfhs_patient_detail_id: 'non-existent-id'
      }
    end

    it 'raises ActiveRecord::RecordNotFound' do
      expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context 'when patient is created with epic_id' do
    before do
      allow_any_instance_of(Date).to receive(:future?).and_return(true)

      allow_any_instance_of(Api::EpicOnFhir::PatientVerification).to receive(:call).and_return(
        JSON.parse(File.read('spec/fixtures/integrations/henry_ford/patient_resource.json')).deep_symbolize_keys
      )
      allow_any_instance_of(Api::EpicOnFhir::Appointments).to receive(:call).and_return(
        JSON.parse(File.read('spec/fixtures/integrations/henry_ford/appointments.json')).deep_symbolize_keys
      )
    end

    it 'stores epic_id in patient detail' do
      patient_resource = JSON.parse(File.read('spec/fixtures/integrations/henry_ford/patient_resource.json')).deep_symbolize_keys
      epic_id = patient_resource.dig(:entry, 0, :resource, :id)

      result = subject
      expect(result.epic_id).to eq(epic_id)
    end
  end
end
