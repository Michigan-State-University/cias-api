# frozen_string_literal: true

require 'rails_helper'

# Drives the whole Aztec-code flow (scan -> Continue) through the controllers and
# pins the invariants it relies on:
#   - a scan never reads or writes an existing row,
#   - only the scanning user can confirm the draft,
#   - the draft stops being pending only once the appointment lookup succeeded.
RSpec.describe 'Aztec code scan and confirm', type: :request do
  let(:scanner) { create(:user, :confirmed, :guest) }
  let(:barcode) { '<PtID>      Z2550</PtID><PtDAT>54348</PtDAT><UID> ML337156</UID>' }
  let(:patient_resource) { JSON.parse(File.read('spec/fixtures/integrations/henry_ford/patient_resource.json')).deep_symbolize_keys }
  let(:epic_id) { patient_resource.dig(:entry, 0, :resource, :id) }
  let(:search_bundle) { patient_resource.merge(total: 1) }
  let!(:session) do
    create(:session,
           intervention: create(:intervention,
                                hfhs_access: true,
                                intervention_locations: [create(:intervention_location,
                                                                clinic_location: create(:clinic_location, name: 'brukowa', department: 'HTD',
                                                                                                          external_id: 'externalID',
                                                                                                          external_name: 'brukowa'))]))
  end

  before do
    create(:question_henry_ford_initial_screen, question_group: create(:question_group, session: session))
    allow_any_instance_of(Date).to receive(:future?).and_return(true)
    allow_any_instance_of(Api::EpicOnFhir::PatientSearch).to receive(:call).and_return(search_bundle)
    allow_any_instance_of(Api::EpicOnFhir::Appointments).to receive(:call).and_return(
      JSON.parse(File.read('spec/fixtures/integrations/henry_ford/appointments.json')).deep_symbolize_keys
    )
  end

  def scan(user)
    create(:user_session, user: user, session: session) unless UserSession.exists?(user: user, session: session)
    post v1_henry_ford_verify_by_code_path, params: { hfhs_patient_data: { barcode: barcode }, session_id: session.id },
                                            headers: user.create_new_auth_token
    expect(response).to have_http_status(:ok)
    response.parsed_body.dig('data', 'id')
  end

  def continue(user, id)
    post v1_henry_ford_verify_path, params: { hfhs_patient_data: { id: id }, session_id: session.id }, headers: user.create_new_auth_token
  end

  it 'confirms the draft without $match, flips pending and links the scanner' do
    expect_any_instance_of(Api::EpicOnFhir::PatientVerification).not_to receive(:call)

    draft_id = scan(scanner)
    continue(scanner, draft_id)

    expect(response).to have_http_status(:ok)
    draft = HfhsPatientDetail.find(draft_id)
    expect(draft.pending).to be false
    expect(draft.visit_id).to eq('_externalID_10022118420')
    expect(draft).to have_attributes(phone_number: '734-999-2828', phone_type: 'mobile')
    expect(scanner.reload.hfhs_patient_detail).to eq(draft)
  end

  it 'does not return the MRN from /verify' do
    continue(scanner, scan(scanner))

    expect(response.parsed_body.dig('data', 'attributes')).not_to have_key('patient_id')
    expect(response.body).not_to include('89010892')
  end

  it "refuses another user's Continue on the draft, with the translated message" do
    draft_id = scan(scanner)
    intruder = create(:user, :confirmed, :guest)

    continue(intruder, draft_id)

    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body['message']).to eq(I18n.t('henry_ford.error.patient.draft_not_found'))
    expect(intruder.reload.hfhs_patient_detail).to be_nil
    expect(HfhsPatientDetail.find(draft_id).pending).to be true
  end

  it 'lets a returning patient finish, without touching their earlier record' do
    earlier_user = create(:user, :confirmed, :guest)
    earlier = create(:hfhs_patient_detail, patient_id: '89010892', first_name: 'Robert', sex: 'M', zip_code: '11111',
                                           phone_type: 'mobile', pending: false)
    earlier_user.update!(hfhs_patient_detail: earlier)
    earlier_attributes = earlier.reload.attributes

    draft_id = scan(scanner)
    expect(draft_id).not_to eq(earlier.id)

    continue(scanner, draft_id)

    expect(response).to have_http_status(:ok)
    expect(scanner.reload.hfhs_patient_detail_id).to eq(draft_id)
    expect(earlier.reload.attributes).to eq(earlier_attributes)
    expect(earlier_user.reload.hfhs_patient_detail).to eq(earlier)
  end

  it 'stores epic_id encrypted and keeps it out of audits and versions' do
    draft = HfhsPatientDetail.find(scan(scanner))
    continue(scanner, draft.id)

    expect(draft.reload.epic_id).to eq(epic_id)
    expect(draft.epic_id_ciphertext).not_to include(epic_id)
    expect(HfhsPatientDetail.column_names).not_to include('epic_id')

    audits = Audited::Audit.where(auditable_type: 'HfhsPatientDetail', auditable_id: draft.id)
    expect(audits).to be_present
    expect(audits.map { |audit| audit.audited_changes.to_json }.join).not_to include(epic_id)
    expect(audits.flat_map { |audit| audit.audited_changes.keys }).not_to include('epic_id', 'epic_id_ciphertext')

    versions = PaperTrail::Version.where(item_type: 'HfhsPatientDetail')
    expect(versions).to be_present
    expect(versions.map { |version| version.object.to_s }.join).not_to include(epic_id)
  end

  describe 'barcode filtering' do
    it 'filters the barcode from the Rails parameter log' do
      filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

      expect(filter.filter('hfhs_patient_data' => { 'barcode' => barcode })).to eq('hfhs_patient_data' => { 'barcode' => '[FILTERED]' })
    end

    it 'keeps the barcode out of the stored user request log' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('LOG_OFF').and_return('false')

      expect { scan(scanner) }.to have_enqueued_job(LogJobs::UserRequest).with { |scope|
        expect(scope.to_json).not_to include('Z2550')
        expect(scope.to_json).not_to include('ML337156')
      }
    end
  end

  describe 'throttle' do
    let(:throttle) { Rack::Attack.throttles.fetch('henry_ford/verify_by_code/ip') }

    def discriminator(path, method: 'POST')
      throttle.block.call(Rack::Attack::Request.new(Rack::MockRequest.env_for(path, method: method, 'REMOTE_ADDR' => '1.2.3.4')))
    end

    it 'covers the bare path and every format suffix' do
      expect(discriminator('/v1/henry_ford/verify_by_code')).to eq('1.2.3.4')
      expect(discriminator('/v1/henry_ford/verify_by_code.json')).to eq('1.2.3.4')
      expect(discriminator('/v1/henry_ford/verify_by_code.xml')).to eq('1.2.3.4')
    end

    it 'also counts per account, on the uid header' do
      user_throttle = Rack::Attack.throttles.fetch('henry_ford/verify_by_code/user')
      request_for = lambda do |path, headers = {}|
        Rack::Attack::Request.new(Rack::MockRequest.env_for(path, { method: 'POST', 'REMOTE_ADDR' => '1.2.3.4' }.merge(headers)))
      end

      expect(user_throttle.block.call(request_for.call('/v1/henry_ford/verify_by_code.json', 'HTTP_UID' => 'a@b.c'))).to eq('a@b.c')
      expect(user_throttle.block.call(request_for.call('/v1/henry_ford/verify_by_code'))).to be_nil
      expect(user_throttle.block.call(request_for.call('/v1/henry_ford/verify', 'HTTP_UID' => 'a@b.c'))).to be_nil
    end

    it 'leaves other paths and verbs alone' do
      expect(discriminator('/v1/henry_ford/verify')).to be_nil
      expect(discriminator('/v1/henry_ford/verify_by_code_other')).to be_nil
      expect(discriminator('/v1/henry_ford/verify_by_code', method: 'GET')).to be_nil
    end
  end
end
