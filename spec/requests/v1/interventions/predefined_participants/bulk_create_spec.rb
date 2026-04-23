# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:intervention_id/predefined_participants/bulk_create', type: :request do
  subject(:request) do
    post bulk_create_v1_intervention_predefined_participants_path(intervention_id: intervention.id),
         params: params, headers: headers
  end

  let!(:researcher) { create(:user, :confirmed, :researcher) }
  let!(:intervention) { create(:intervention, user_id: researcher.id) }
  let(:current_user) { researcher }
  let(:headers) { current_user.create_new_auth_token }

  # `after_action :leave_footprint` in V1Controller enqueues `LogJobs::UserRequest`
  # on every request — unrelated to this feature. Filter to BulkImportJob so the
  # log-job noise doesn't pollute enqueue assertions.
  def bulk_import_jobs
    ActiveJob::Base.queue_adapter.enqueued_jobs
                   .select { |j| j[:job] == PredefinedParticipants::BulkImportJob }
  end

  def participant_attrs(overrides = {})
    { first_name: 'Alice', last_name: 'Smith' }.merge(overrides)
  end

  def wrap(*participants)
    { predefined_users: { participants: participants } }
  end

  describe 'scenario 1 — valid participants, no variable_answers' do
    let(:params) { wrap(participant_attrs(email: 'p1@example.test')) }

    it 'returns 202' do
      request
      expect(response).to have_http_status(:accepted)
    end

    it 'creates exactly one BulkImportPayload' do
      expect { request }.to change(BulkImportPayload, :count).by(1)
    end

    it 'enqueues BulkImportJob with the payload UUID as its only arg' do
      expect { request }.to change { bulk_import_jobs.size }.by(1) # rubocop:disable RSpec/ExpectChange
      job = bulk_import_jobs.last
      expect(job[:args]).to eq([BulkImportPayload.last.id])
    end
  end

  describe 'scenario 2 — valid participants + valid variable_answers' do
    let!(:ra_session) { create(:ra_session, intervention: intervention, variable: 's1') }
    let!(:question_group) { create(:question_group, session: ra_session) }
    let!(:single_question) do
      create(:question_single,
             question_group: question_group,
             body: {
               'data' => [{ 'payload' => 'Opt 1', 'value' => '1' }, { 'payload' => 'Opt 2', 'value' => '2' }],
               'variable' => { 'name' => 'mood' }
             })
    end
    let(:params) do
      wrap(participant_attrs(email: 'p1@example.test', variable_answers: { 's1.mood' => '1' }))
    end

    it 'returns 202' do
      request
      expect(response).to have_http_status(:accepted)
    end

    it 'creates a BulkImportPayload carrying both attributes and variable_answers' do
      expect { request }.to change(BulkImportPayload, :count).by(1)
      payload = BulkImportPayload.last.payload
      expect(payload.size).to eq(1)
      expect(payload.first['attributes']).to include('email' => 'p1@example.test', 'first_name' => 'Alice')
      expect(payload.first['attributes']).not_to have_key('variable_answers')
      expect(payload.first['variable_answers']).to eq('s1.mood' => '1')
    end

    it 'enqueues BulkImportJob with the payload id only' do
      expect { request }.to change { bulk_import_jobs.size }.by(1) # rubocop:disable RSpec/ExpectChange
      job = bulk_import_jobs.last
      expect(job[:args]).to eq([BulkImportPayload.last.id])
    end
  end

  describe 'scenario 3 — duplicate email within CSV' do
    let(:params) do
      wrap(
        participant_attrs(email: 'dup@example.test'),
        participant_attrs(email: 'dup@example.test')
      )
    end

    it 'returns 422, no payload created, no BulkImportJob enqueued' do
      expect { request }.not_to change(BulkImportPayload, :count)
      expect(bulk_import_jobs).to be_empty
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'scenario 4 — duplicate email against DB' do
    let!(:existing) { create(:user, :confirmed, email: 'taken@example.test') }
    let(:params) { wrap(participant_attrs(email: existing.email)) }

    it 'returns 422, no payload created, no BulkImportJob enqueued' do
      expect { request }.not_to change(BulkImportPayload, :count)
      expect(bulk_import_jobs).to be_empty
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # Scenario 5 (plan) — "missing required field (e.g. first_name blank)" — dropped.
  # Predefined participants can be created without first_name elsewhere in the app
  # (sync create, update); making it required only here would be inconsistent. The
  # "invalid participant attributes → 422" path is covered by scenarios 4 (taken
  # email), 6 (phone), 7 (clinic), and 14 (fail-fast with invalid email format).

  describe 'scenario 6 — invalid phone' do
    let(:params) do
      wrap(participant_attrs(email: 'p@example.test', phone_attributes: { iso: '', prefix: '', number: '' }))
    end

    it 'returns 422, no payload created, no BulkImportJob enqueued' do
      expect { request }.not_to change(BulkImportPayload, :count)
      expect(bulk_import_jobs).to be_empty
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'scenario 7 — invalid health_clinic_id' do
    let(:params) { wrap(participant_attrs(email: 'p@example.test', health_clinic_id: SecureRandom.uuid)) }

    it 'returns 422 with not_found on health_clinic_id' do
      expect { request }.not_to change(BulkImportPayload, :count)
      expect(bulk_import_jobs).to be_empty
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['details']['errors']).to include(
        a_hash_including('field' => 'health_clinic_id', 'code' => 'not_found')
      )
    end
  end

  describe 'scenario 8 — invalid variable name (unknown question variable)' do
    let!(:ra_session) { create(:ra_session, intervention: intervention, variable: 's1') }
    let(:params) do
      wrap(participant_attrs(email: 'p@example.test', variable_answers: { 's1.nonexistent' => '1' }))
    end
    let!(:question_group) { create(:question_group, session: ra_session) }

    before do
      create(:question_single,
             question_group: question_group,
             body: { 'data' => [{ 'payload' => 'A', 'value' => '1' }], 'variable' => { 'name' => 'mood' } })
    end

    it 'returns 422 with unknown_question_variable, no payload, no enqueue' do
      expect { request }.not_to change(BulkImportPayload, :count)
      expect(bulk_import_jobs).to be_empty
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['details']['errors']).to include(
        a_hash_including('field' => 's1.nonexistent', 'code' => 'unknown_question_variable')
      )
    end
  end

  describe 'scenario 9 — unsupported question type (Multiple) in variable_answers' do
    let!(:ra_session) { create(:ra_session, intervention: intervention, variable: 's1') }
    let(:params) { wrap(participant_attrs(email: 'p@example.test', variable_answers: { 's1.picks' => '1' })) }
    let!(:question_group) { create(:question_group, session: ra_session) }

    before do
      create(:question_multiple,
             question_group: question_group,
             body: { 'data' => [{ 'payload' => 'Opt', 'variable' => { 'name' => 'picks', 'value' => '1' } }] })
    end

    it 'returns 422 with unsupported_question_type, no payload, no enqueue' do
      expect { request }.not_to change(BulkImportPayload, :count)
      expect(bulk_import_jobs).to be_empty
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['details']['errors']).to include(
        a_hash_including('field' => 's1.picks', 'code' => 'unsupported_question_type')
      )
    end
  end

  describe 'scenario 10 — invalid value for Single / Number / Date' do
    let!(:ra_session) { create(:ra_session, intervention: intervention, variable: 's1') }
    let(:params) do
      wrap(participant_attrs(
             email: 'p@example.test',
             variable_answers: { 's1.mood' => '999', 's1.score' => 'abc', 's1.visit_date' => 'not-a-date' }
           ))
    end
    let!(:question_group) { create(:question_group, session: ra_session) }

    before do
      create(:question_single,
             question_group: question_group,
             body: { 'data' => [{ 'payload' => 'A', 'value' => '1' }], 'variable' => { 'name' => 'mood' } })
      create(:question_number,
             question_group: question_group,
             body: { 'data' => [{ 'payload' => 'Score' }], 'variable' => { 'name' => 'score' } })
      create(:question_date,
             question_group: question_group,
             body: { 'data' => [{ 'payload' => 'Visit' }], 'variable' => { 'name' => 'visit_date' } })
    end

    it 'returns 422 with per-field codes, no payload, no enqueue' do
      expect { request }.not_to change(BulkImportPayload, :count)
      expect(bulk_import_jobs).to be_empty
      expect(response).to have_http_status(:unprocessable_entity)
      errors = json_response['details']['errors']
      expect(errors).to include(a_hash_including('field' => 's1.mood', 'code' => 'value_not_in_options'))
      expect(errors).to include(a_hash_including('field' => 's1.score', 'code' => 'value_not_a_number'))
      expect(errors).to include(a_hash_including('field' => 's1.visit_date', 'code' => 'value_not_a_date'))
    end
  end

  describe 'scenario 11 — no RA session but variable_answers supplied' do
    let(:params) do
      wrap(participant_attrs(email: 'p@example.test', variable_answers: { 's1.mood' => '1' }))
    end

    it 'returns 422 with ra_session_missing, no payload, no enqueue' do
      expect { request }.not_to change(BulkImportPayload, :count)
      expect(bulk_import_jobs).to be_empty
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['details']['errors']).to include(a_hash_including('code' => 'ra_session_missing'))
    end
  end

  describe 'scenario 12 — blank value in variable_answers' do
    let!(:ra_session) { create(:ra_session, intervention: intervention, variable: 's1') }
    let(:params) { wrap(participant_attrs(email: 'p@example.test', variable_answers: { 's1.mood' => '' })) }
    let!(:question_group) { create(:question_group, session: ra_session) }

    before do
      create(:question_single,
             question_group: question_group,
             body: { 'data' => [{ 'payload' => 'A', 'value' => '1' }], 'variable' => { 'name' => 'mood' } })
    end

    it 'returns 422 with value_blank, no payload, no enqueue' do
      expect { request }.not_to change(BulkImportPayload, :count)
      expect(bulk_import_jobs).to be_empty
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['details']['errors']).to include(a_hash_including('code' => 'value_blank'))
    end
  end

  describe 'scenario 13 — empty participants array (controller early-reject)' do
    let(:params) { { predefined_users: { participants: [] } } }

    it 'returns 422 with empty_participants code without invoking validators' do
      expect(V1::Intervention::PredefinedParticipants::ParticipantAttributesValidator).not_to receive(:call)
      expect(V1::Intervention::PredefinedParticipants::VariableAnswersValidator).not_to receive(:call)

      expect { request }.not_to change(BulkImportPayload, :count)
      expect(bulk_import_jobs).to be_empty
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['details']['errors']).to include(a_hash_including('code' => 'empty_participants'))
    end
  end

  describe 'scenario 14 — fail-fast: participant-attr errors surface WITHOUT variable-answer errors' do
    let!(:ra_session) { create(:ra_session, intervention: intervention, variable: 's1') }
    let(:params) do
      wrap(participant_attrs(
        # Participant-attr failure: invalid email format.
        email: 'not-an-email',
        # Variable-answer failure that would trip if reached: out-of-options.
        variable_answers: { 's1.mood' => '999' }
      ))
    end
    let!(:question_group) { create(:question_group, session: ra_session) }

    before do
      create(:question_single,
             question_group: question_group,
             body: { 'data' => [{ 'payload' => 'A', 'value' => '1' }], 'variable' => { 'name' => 'mood' } })
    end

    it 'returns only participant-attr errors; variable-answer validator is not invoked; no payload; no enqueue' do
      expect(V1::Intervention::PredefinedParticipants::VariableAnswersValidator).not_to receive(:call)

      expect { request }.not_to change(BulkImportPayload, :count)
      expect(bulk_import_jobs).to be_empty
      expect(response).to have_http_status(:unprocessable_entity)
      errors = json_response['details']['errors']
      expect(errors.pluck('field')).to include('email')
      expect(errors.pluck('field')).not_to include('s1.mood')
    end
  end

  describe 'scenario 15a — HIPAA: 422 body contains zero PII' do
    let!(:ra_session) { create(:ra_session, intervention: intervention, variable: 's1') }
    let(:email) { 'leaktest@example.test' }
    let(:first_name) { 'Eleanor' }
    let(:last_name) { 'Rigby' }
    let(:phone_number) { '5551234567' }
    let(:raw_answer) { 'SENSITIVE_VALUE_XYZ' }
    let!(:existing) { create(:user, :confirmed, email: email) } # forces a taken error
    let(:params) do
      # Bad phone (blank iso/prefix) + taken email + out-of-options answer →
      # exercises all three validator failure paths in one response.
      wrap(participant_attrs(
             first_name: first_name, last_name: last_name, email: email,
             phone_attributes: { iso: '', prefix: '', number: phone_number },
             variable_answers: { 's1.mood' => raw_answer }
           ))
    end
    let!(:question_group) { create(:question_group, session: ra_session) }

    before do
      create(:question_single,
             question_group: question_group,
             body: { 'data' => [{ 'payload' => 'A', 'value' => '1' }], 'variable' => { 'name' => 'mood' } })
    end

    it 'error hashes carry only structural keys and stable codes — no PII leaks; no payload; no enqueue' do
      expect { request }.not_to change(BulkImportPayload, :count)
      expect(bulk_import_jobs).to be_empty
      expect(response).to have_http_status(:unprocessable_entity)
      errors = json_response['details']['errors']
      expect(errors).not_to be_empty

      errors.each do |entry|
        expect(entry).to include('row', 'field', 'code')
        expect(entry['row']).to be_a(Integer)
        expect(entry['field']).to be_a(String)
        expect(entry['code']).to be_a(String)
      end

      serialised = errors.to_s
      [email, first_name, last_name, phone_number, raw_answer].each do |pii|
        expect(serialised).not_to include(pii)
      end
    end
  end

  describe 'scenario 15b — HIPAA: BulkImportJob is enqueued with only the UUID in args' do
    let(:params) { wrap(participant_attrs(email: 'alice@example.test')) }

    it 'BulkImportJob args == [uuid] — no hashes, no PII' do
      expect { request }.to change { bulk_import_jobs.size }.by(1) # rubocop:disable RSpec/ExpectChange

      job = bulk_import_jobs.last
      expect(job[:args].size).to eq(1)
      expect(job[:args].first).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)

      serialised = job[:args].to_s
      %w[alice@example.test Alice Smith].each do |pii|
        expect(serialised).not_to include(pii)
      end
    end
  end

  describe 'authorization' do
    let(:params) { wrap(participant_attrs(email: 'p@example.test')) }

    context 'another researcher (no access to this intervention)' do
      let(:current_user) { create(:user, :researcher, :confirmed) }

      it 'returns 404 (intervention not accessible_by)' do
        request
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'a participant (wrong role)' do
      let(:current_user) { create(:user, :participant, :confirmed) }

      it 'returns 403' do
        request
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
