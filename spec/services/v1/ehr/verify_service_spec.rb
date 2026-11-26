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
  let(:patient_resource) { JSON.parse(File.read('spec/fixtures/integrations/epic_on_fhir/patient_resource.json')).deep_symbolize_keys }
  let(:appointments_resource) { JSON.parse(File.read('spec/fixtures/integrations/epic_on_fhir/appointments.json')).deep_symbolize_keys }
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
        JSON.parse(File.read('spec/fixtures/integrations/epic_on_fhir/patient_resource.json')).deep_symbolize_keys
      )
      allow_any_instance_of(Api::EpicOnFhir::Appointments).to receive(:call).and_return(
        JSON.parse(File.read('spec/fixtures/integrations/epic_on_fhir/appointments.json')).deep_symbolize_keys
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

    context 'with the HL7 settings configured' do
      include_context 'with HL7 settings configured'

      it 'stores the sex in HL7 format and sends it as such in PID.8' do
        subject
        expect(user.reload.hfhs_patient_detail.sex).to eq('M')

        user_session = create(:user_session, user: user, session: session)
        pid = Hl7::PatientDataMapper.call(user.id, user_session.id, 'ORU', 'R01').find { |segment| segment.start_with?('PID') }
        expect(pid).to end_with('|M')
      end
    end

    it 'confirms the record' do
      expect(subject.pending).to be false
    end

    context 'when Epic has no home address' do
      before do
        patient_resource[:entry][0][:resource][:address] = [{ use: 'old', postalCode: '48202' }]
        allow_any_instance_of(Api::EpicOnFhir::PatientVerification).to receive(:call).and_return(patient_resource)
      end

      it 'falls back to the zip code the participant provided' do
        expect(subject.zip_code).to eq(params['zip_code'])
      end
    end

    context 'when the patient was verified before epic_id was stored' do
      let!(:legacy_detail) do
        create(:hfhs_patient_detail,
               patient_id: '89010892',
               first_name: 'Medicaid',
               last_name: 'Korody',
               dob: Date.parse(patient_resource.dig(:entry, 0, :resource, :birthDate)),
               sex: 'M',
               zip_code: '48202',
               phone_type: 'home',
               phone_number: '734-298-8292',
               provided_first_name: params['first_name'],
               provided_last_name: params['last_name'],
               provided_dob: params['dob'],
               provided_sex: params['sex'],
               provided_zip: params['zip_code'],
               provided_phone_type: params['phone_type'].to_s,
               provided_phone_number: params['phone_number'])
      end

      it 'reuses the existing record and fills in epic_id' do
        expect { subject }.not_to change(HfhsPatientDetail, :count)
        expect(subject.id).to eq(legacy_detail.id)
        expect(legacy_detail.reload.epic_id).to eq(patient_resource.dig(:entry, 0, :resource, :id))
      end
    end
  end

  context 'when the manual appointment lookup fails' do
    before do
      allow_any_instance_of(Api::EpicOnFhir::PatientVerification).to receive(:call).and_return(patient_resource)
      allow_any_instance_of(Api::EpicOnFhir::Appointments).to receive(:call).
        and_raise(EpicOnFhir::NotFound, I18n.t('epic_on_fhir.error.appointments.not_found'))
    end

    it 'does not leave an unlinked patient record behind' do
      expect { subject }.to raise_error(EpicOnFhir::NotFound).and(avoid_changing(HfhsPatientDetail, :count))
    end
  end

  context 'when patient doesn\'t have appointment in the future' do
    before do
      allow_any_instance_of(Api::EpicOnFhir::PatientVerification).to receive(:call).and_return(
        JSON.parse(File.read('spec/fixtures/integrations/epic_on_fhir/patient_resource.json')).deep_symbolize_keys
      )
      allow_any_instance_of(Api::EpicOnFhir::Appointments).to receive(:call).and_return(
        JSON.parse(File.read('spec/fixtures/integrations/epic_on_fhir/appointments.json')).deep_symbolize_keys
      )
    end

    context 'when past appointments are not allowed' do
      include_context 'with environment variables', { 'EHR_APPOINTMENTS_FROM_PAST' => '' }

      it 'raise exception' do
        expect { subject }.to raise_error(EpicOnFhir::NotFound)
      end
    end

    context 'when EHR_APPOINTMENTS_FROM_PAST allows past appointments' do
      include_context 'with environment variables', { 'EHR_APPOINTMENTS_FROM_PAST' => '1' }

      it 'matches the past appointment' do
        expect(subject.visit_id).to eql('_externalID_10022118420')
      end
    end
  end

  context 'when id is provided' do
    let!(:existing_patient_detail) do
      create(:hfhs_patient_detail,
             patient_id: '89010892',
             first_name: 'John',
             last_name: 'Doe',
             dob: Date.parse('1980-01-01'),
             sex: 'M',
             zip_code: '12345',
             phone_type: 'mobile',
             phone_number: '+1234567890',
             epic_id: 'test-epic-id-123',
             pending: true,
             drafted_by: user)
    end

    let(:params) do
      {
        id: existing_patient_detail.id
      }
    end

    before do
      allow_any_instance_of(Date).to receive(:future?).and_return(true)

      allow_any_instance_of(Api::EpicOnFhir::PatientVerification).to receive(:call).and_return(
        JSON.parse(File.read('spec/fixtures/integrations/epic_on_fhir/patient_resource.json')).deep_symbolize_keys
      )
      allow_any_instance_of(Api::EpicOnFhir::Appointments).to receive(:call).and_return(
        JSON.parse(File.read('spec/fixtures/integrations/epic_on_fhir/appointments.json')).deep_symbolize_keys
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

  context 'when id points at a confirmed record this user is not matched to' do
    let!(:someone_elses_detail) { create(:hfhs_patient_detail, patient_id: '89010892', epic_id: 'test-epic-id-123', pending: false) }
    let(:params) { { id: someone_elses_detail.id } }

    it 'refuses to confirm it' do
      expect { subject }.to raise_error(ActiveRecord::RecordNotFound, I18n.t('ehr.error.patient.draft_not_found'))
    end

    it 'does not match the user to it' do
      expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
      expect(user.reload.hfhs_patient_detail).to be_nil
    end
  end

  context "when id points at another user's pending draft" do
    let!(:other_draft) do
      create(:hfhs_patient_detail, patient_id: '89010892', epic_id: 'test-epic-id-123', pending: true,
                                   drafted_by: create(:user, :confirmed, :guest))
    end
    let(:params) { { id: other_draft.id } }

    it 'refuses to confirm it without calling Epic' do
      expect_any_instance_of(Api::EpicOnFhir::Appointments).not_to receive(:call)
      expect { subject }.to raise_error(ActiveRecord::RecordNotFound, I18n.t('ehr.error.patient.draft_not_found'))
    end

    it 'leaves the draft pending and the user unmatched' do
      expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
      expect(other_draft.reload.pending).to be true
      expect(user.reload.hfhs_patient_detail).to be_nil
    end
  end

  context 'when id points at an own draft without an epic_id' do
    let!(:draft) { create(:hfhs_patient_detail, patient_id: '89010892', pending: true, drafted_by: user) }
    let(:params) { { id: draft.id } }

    it 'refuses it instead of running an unscoped appointment search' do
      expect_any_instance_of(Api::EpicOnFhir::Appointments).not_to receive(:call)
      expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context 'when the appointment lookup for an own draft fails' do
    let!(:draft) do
      create(:hfhs_patient_detail, patient_id: '89010892', epic_id: 'test-epic-id-123', pending: true, drafted_by: user)
    end
    let(:params) { { id: draft.id } }

    before do
      allow_any_instance_of(Date).to receive(:future?).and_return(true)
      call_count = 0
      allow_any_instance_of(Api::EpicOnFhir::Appointments).to receive(:call) do
        call_count += 1
        raise EpicOnFhir::NotFound, I18n.t('epic_on_fhir.error.appointments.not_found') if call_count == 1

        appointments_resource
      end
    end

    it 'keeps the draft pending so the same user can retry' do
      expect { described_class.new(user, params, session.id).call }.to raise_error(EpicOnFhir::NotFound)
      expect(draft.reload.pending).to be true
      expect(user.reload.hfhs_patient_detail).to be_nil

      expect(described_class.new(user, params, session.id).call).to eq(draft)
      expect(draft.reload.pending).to be false
      expect(user.reload.hfhs_patient_detail).to eq(draft)
    end
  end

  context 'when a preview user confirms an own draft' do
    let(:user) { create(:user, :confirmed, :preview_session) }
    let!(:draft) do
      create(:hfhs_patient_detail, patient_id: '89010892', epic_id: 'test-epic-id-123', pending: true, drafted_by: user)
    end
    let(:params) { { id: draft.id } }

    before do
      allow_any_instance_of(Date).to receive(:future?).and_return(true)
      allow_any_instance_of(Api::EpicOnFhir::Appointments).to receive(:call).and_return(appointments_resource)
    end

    it 'leaves the draft pending (it expires instead of becoming an unmatched confirmed row)' do
      subject
      expect(draft.reload.pending).to be true
      expect(draft.visit_id).to eq('_externalID_10022118420')
    end
  end

  context 'when id points at the record this user is already matched to' do
    let!(:own_detail) { create(:hfhs_patient_detail, patient_id: '89010892', epic_id: 'test-epic-id-123', pending: false) }
    let(:params) { { id: own_detail.id } }

    before do
      user.update!(hfhs_patient_detail: own_detail)
      allow_any_instance_of(Date).to receive(:future?).and_return(true)
      allow_any_instance_of(Api::EpicOnFhir::Appointments).to receive(:call).and_return(
        JSON.parse(File.read('spec/fixtures/integrations/epic_on_fhir/appointments.json')).deep_symbolize_keys
      )
    end

    it 'confirms it' do
      expect(subject).to eq(own_detail.reload)
    end
  end

  context 'when id is provided but record not found' do
    let(:params) do
      {
        id: 'non-existent-id'
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
        JSON.parse(File.read('spec/fixtures/integrations/epic_on_fhir/patient_resource.json')).deep_symbolize_keys
      )
      allow_any_instance_of(Api::EpicOnFhir::Appointments).to receive(:call).and_return(
        JSON.parse(File.read('spec/fixtures/integrations/epic_on_fhir/appointments.json')).deep_symbolize_keys
      )
    end

    it 'stores epic_id in patient detail' do
      patient_resource = JSON.parse(File.read('spec/fixtures/integrations/epic_on_fhir/patient_resource.json')).deep_symbolize_keys
      epic_id = patient_resource.dig(:entry, 0, :resource, :id)

      result = subject
      expect(result.epic_id).to eq(epic_id)
    end
  end
end
