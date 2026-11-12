# frozen_string_literal: true

RSpec.describe V1::Ehr::VerifyService do
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

    context 'when past appointments are not allowed' do
      include_context 'with environment variables', { 'EHR_APPOINTMENTS_FROM_PAST' => '', 'HFHS_APPOINTMENTS_FROM_PAST' => nil }

      it 'raise exception' do
        expect { subject }.to raise_error(EpicOnFhir::NotFound)
      end
    end

    {
      'EHR_APPOINTMENTS_FROM_PAST' => { 'EHR_APPOINTMENTS_FROM_PAST' => '1', 'HFHS_APPOINTMENTS_FROM_PAST' => nil },
      'only the old HFHS_APPOINTMENTS_FROM_PAST' => { 'EHR_APPOINTMENTS_FROM_PAST' => '', 'HFHS_APPOINTMENTS_FROM_PAST' => '1' }
    }.each do |description, settings|
      context "when #{description} allows past appointments" do
        include_context 'with environment variables', settings

        it 'matches the past appointment' do
          expect(subject.visit_id).to eql('_externalID_10022118420')
        end
      end
    end

    context 'when EHR_APPOINTMENTS_FROM_PAST is 0 and the old name is 1' do
      include_context 'with environment variables', { 'EHR_APPOINTMENTS_FROM_PAST' => '0', 'HFHS_APPOINTMENTS_FROM_PAST' => '1' }

      it 'follows the new name' do
        expect { subject }.to raise_error(EpicOnFhir::NotFound)
      end
    end
  end
end
