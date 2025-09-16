# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/interventions/:intervention_id/sessions/bulk_update', type: :request do
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
      sessions: [
        {
          id: session1.id,
          schedule: 'after_fill',
          schedule_payload: nil,
          schedule_at: nil
        },
        {
          id: session2.id,
          schedule: 'exact_date',
          schedule_payload: nil,
          schedule_at: '2025-12-25T10:00:00Z'
        }
      ]
    }
  end

  let(:request) do
    patch "/v1/interventions/#{intervention.id}/sessions/bulk_update",
          params: valid_params,
          headers: headers
  end

  shared_examples 'permitted user' do
    context 'when params are valid' do
      before { request }

      it 'returns success status' do
        expect(response).to have_http_status(:success)
      end

      it 'updates the sessions' do
        session1.reload
        session2.reload

        expect(session1.schedule).to eq('after_fill')
        expect(session2.schedule).to eq('exact_date')
        expect(session2.schedule_at.to_date).to eq(Date.parse('2025-12-25'))
      end

      it 'returns updated sessions in response' do
        response_body = response.parsed_body
        expect(response_body['data']).to be_an(Array)
        expect(response_body['data'].length).to eq(2)

        session_ids = response_body['data'].pluck('id')
        expect(session_ids).to contain_exactly(session1.id, session2.id)
      end
    end

    context 'when session does not belong to intervention' do
      let(:other_intervention) { create(:intervention) }
      let(:other_session) { create(:session, intervention: other_intervention) }
      let(:invalid_params) do
        {
          sessions: [
            {
              id: other_session.id,
              schedule: 'after_fill'
            }
          ]
        }
      end

      before do
        patch "/v1/interventions/#{intervention.id}/sessions/bulk_update",
              params: invalid_params,
              headers: headers
      end

      it 'returns unprocessable entity status' do
        expect(response).to have_http_status(:not_found)
      end

      it 'returns error message' do
        response_body = response.parsed_body
        expect(response_body['message']).to eq('Some sessions not found or unauthorized')
      end
    end

    context 'when session id does not exist' do
      let(:invalid_params) do
        {
          sessions: [
            {
              id: 'non-existent-id',
              schedule: 'after_fill'
            }
          ]
        }
      end

      before do
        patch "/v1/interventions/#{intervention.id}/sessions/bulk_update",
              params: invalid_params,
              headers: headers
      end

      it 'returns unprocessable entity status' do
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when no sessions provided' do
      let(:empty_params) { { sessions: [] } }

      before do
        patch "/v1/interventions/#{intervention.id}/sessions/bulk_update",
              params: empty_params,
              headers: headers
      end

      it 'returns success status' do
        expect(response).to have_http_status(:success)
      end

      it 'returns empty array' do
        response_body = response.parsed_body
        expect(response_body['data']).to eq([])
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

    it 'returns not found status' do
      expect(response).to have_http_status(:not_found)
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
end
