# frozen_string_literal: true

RSpec.describe V1::HenryFord::VerifyService do
  let(:subject) { described_class.new(user, params).call }
  let(:user) { create(:user, :participant, :confirmed) }
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
  end
end
