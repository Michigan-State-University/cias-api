# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/interventions/:intervention_id/sessions/update_all_schedules', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:user) { admin }
  let(:intervention) { create(:intervention, user: admin) }
  let!(:session1) { create(:session, intervention: intervention, schedule: 'immediately') }
  let!(:session2) { create(:session, intervention: intervention, schedule: 'immediately') }
  let!(:session3) { create(:session, intervention: intervention, schedule: 'days_after') }
  let(:headers) { user.create_new_auth_token }

  let(:valid_params) do
    {
      session: {
        schedule: 'after_fill',
        schedule_payload: nil,
        schedule_at: nil
      }
    }
  end

  let(:request) do
    patch "/v1/interventions/#{intervention.id}/sessions/update_all_schedules",
          params: valid_params,
          headers: headers
  end

  shared_examples 'permitted user' do
    context 'when params are valid' do
      before { request }

      it 'returns success status' do
        expect(response).to have_http_status(:success)
      end

      it 'updates all sessions with the same schedule' do
        session1.reload
        session2.reload
        session3.reload

        expect(session1.schedule).to eq('after_fill')
        expect(session2.schedule).to eq('after_fill')
        expect(session3.schedule).to eq('after_fill')
      end

      it 'returns all updated sessions in response' do
        response_body = response.parsed_body
        expect(response_body['data']).to be_an(Array)
        expect(response_body['data'].length).to eq(3)

        session_ids = response_body['data'].pluck('id')
        expect(session_ids).to contain_exactly(session1.id, session2.id, session3.id)
      end
    end

    context 'with schedule_at parameter' do
      let(:schedule_params) do
        {
          session: {
            schedule: 'exact_date',
            schedule_payload: nil,
            schedule_at: '2025-12-25T10:00:00Z'
          }
        }
      end

      before do
        patch "/v1/interventions/#{intervention.id}/sessions/update_all_schedules",
              params: schedule_params,
              headers: headers
      end

      it 'returns success status' do
        expect(response).to have_http_status(:success)
      end

      it 'updates all sessions with the same schedule_at' do
        session1.reload
        session2.reload
        session3.reload

        expect(session1.schedule).to eq('exact_date')
        expect(session2.schedule).to eq('exact_date')
        expect(session3.schedule).to eq('exact_date')
        expect(session1.schedule_at.to_date).to eq(Date.parse('2025-12-25'))
        expect(session2.schedule_at.to_date).to eq(Date.parse('2025-12-25'))
        expect(session3.schedule_at.to_date).to eq(Date.parse('2025-12-25'))
      end
    end
  end

  context 'when user is admin' do
    let(:user) { admin }

    it_behaves_like 'permitted user'
  end

  context 'when user is researcher and owns intervention' do
    let(:user) { researcher }
    let(:intervention) { create(:intervention, user: researcher) }

    it_behaves_like 'permitted user'
  end

  context 'when user is participant' do
    let(:user) { participant }

    before { request }

    it 'returns forbidden status' do
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when user does not own intervention' do
    let(:user) { researcher }
    let(:other_user) { create(:user, :confirmed, :researcher) }
    let(:intervention) { create(:intervention, user: other_user) }

    before { request }

    it 'returns forbidden status' do
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when intervention is published' do
    let(:user) { admin }
    let(:intervention) { create(:intervention, :published, user: admin) }

    before { request }

    it 'returns success status (published interventions allow session updates)' do
      expect(response).to have_http_status(:success)
    end
  end

  context 'when the owner researcher updates the schedules' do
    let(:user) { researcher }
    let(:intervention) { create(:intervention, user: researcher) }

    before { request }

    context 'when the attributes are sent as JSON without the session key' do
      let(:request) do
        patch "/v1/interventions/#{intervention.id}/sessions/update_all_schedules",
              params: { schedule: 'days_after', schedule_payload: 3, schedule_at: nil },
              headers: headers, as: :json
      end

      it 'stores and returns the schedule and its payload of every session' do
        expect(response).to have_http_status(:ok)
        expect([session1, session2, session3].map { |session| session.reload.slice(:schedule, :schedule_payload).values })
          .to all(eq(['days_after', 3]))
        expect(json_response['data'].map { |session| session['attributes'].slice('schedule', 'schedule_payload') })
          .to all(eq('schedule' => 'days_after', 'schedule_payload' => 3))
      end
    end
  end
end
