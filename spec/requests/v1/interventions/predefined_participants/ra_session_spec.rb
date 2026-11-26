# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'RA session endpoints', type: :request do
  describe 'POST /v1/predefined_participants/:slug/ra_session' do
    let(:researcher) { create(:user, :researcher, :confirmed) }
    let(:intervention) { create(:intervention, :published, user: researcher) }
    let!(:ra_session) { create(:ra_session, intervention: intervention) }
    let(:participant) { create(:user, :confirmed, :predefined_participant) }
    let!(:predefined_user_parameter) { create(:predefined_user_parameter, intervention: intervention, user: participant) }
    let(:slug) { predefined_user_parameter.slug }
    let(:headers) { researcher.create_new_auth_token }

    let(:request) do
      post "/v1/predefined_participants/#{slug}/ra_session", headers: headers
    end

    context 'when researcher initiates RA fulfillment' do
      it 'returns ok status' do
        request
        expect(response).to have_http_status(:ok)
      end

      it 'returns expected data fields' do
        request
        data = json_response['data']
        expect(data['user_session_id']).to be_present
        expect(data['session_id']).to eq(ra_session.id)
        expect(data['intervention_id']).to eq(intervention.id)
        expect(data['already_completed']).to be(false)
        expect(data['lang']).to be_present
      end

      it 'creates a UserIntervention for the participant' do
        expect { request }.to change(UserIntervention, :count).by(1)
      end

      it 'creates a UserSession::ResearchAssistant' do
        expect { request }.to change(UserSession::ResearchAssistant, :count).by(1)
      end

      it 'hands back the same user session when called again' do
        request
        first_id = json_response['data']['user_session_id']
        expect { request }.not_to change(UserSession::ResearchAssistant, :count)
        expect(json_response['data']['user_session_id']).to eq(first_id)
      end

      it 'stamps fulfilled_by_id with the researcher' do
        request
        user_session = UserSession::ResearchAssistant.last
        expect(user_session.fulfilled_by_id).to eq(researcher.id)
      end
    end

    context 'when the RA session was already completed for this participant' do
      let!(:user_intervention) { create(:user_intervention, user: participant, intervention: intervention) }
      let!(:existing_user_session) do
        create(:ra_user_session, session: ra_session, user: participant,
                                 user_intervention: user_intervention, finished_at: 1.day.ago)
      end

      it 'returns ok with already_completed flag' do
        request
        data = json_response['data']
        expect(data['already_completed']).to be(true)
      end

      it 'does not create a new user session' do
        expect { request }.not_to change(UserSession::ResearchAssistant, :count)
      end
    end

    context 'when a different researcher takes over fulfillment' do
      let(:original_researcher) { create(:user, :researcher, :confirmed) }
      let!(:user_intervention) { create(:user_intervention, user: participant, intervention: intervention) }
      let!(:existing_user_session) do
        create(:ra_user_session, session: ra_session, user: participant,
                                 user_intervention: user_intervention, fulfilled_by: original_researcher)
      end

      it 'updates fulfilled_by_id to the current researcher' do
        expect(existing_user_session.fulfilled_by_id).to eq(original_researcher.id)
        request
        expect(existing_user_session.reload.fulfilled_by_id).to eq(researcher.id)
      end
    end

    context 'when intervention is not published (draft)' do
      let(:intervention) { create(:intervention, user: researcher) }

      it 'returns bad_request' do
        request
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when user is a participant (not authorized)' do
      let(:headers) { participant.create_new_auth_token }

      it 'returns forbidden' do
        request
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when intervention has no RA session' do
      before { ra_session.destroy }

      it 'returns not_found' do
        request
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /v1/user_sessions/:id/ra_show' do
    let(:researcher) { create(:user, :researcher, :confirmed) }
    let(:intervention) { create(:intervention, :published, user: researcher) }
    let!(:ra_session) { create(:ra_session, intervention: intervention) }
    let(:participant) { create(:user, :confirmed, :predefined_participant) }
    let(:user_intervention) { create(:user_intervention, user: participant, intervention: intervention) }
    let!(:ra_user_session) do
      create(:ra_user_session, session: ra_session, user: participant,
                               user_intervention: user_intervention, fulfilled_by: researcher)
    end
    let(:headers) { researcher.create_new_auth_token }

    let(:request) do
      get "/v1/user_sessions/#{ra_user_session.id}/ra_show", headers: headers
    end

    context 'when the fulfiller requests the session' do
      it 'returns ok status' do
        request
        expect(response).to have_http_status(:ok)
      end

      it 'returns serialized user session' do
        request
        expect(json_response['data']).to be_present
        expect(json_response['data']['id']).to eq(ra_user_session.id)
      end
    end

    context 'when a different researcher tries to access' do
      let(:other_researcher) { create(:user, :researcher, :confirmed) }
      let(:headers) { other_researcher.create_new_auth_token }

      it 'returns forbidden' do
        request
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when intervention is paused' do
      before { intervention.update!(status: 'paused') }

      it 'returns bad_request' do
        request
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when user is a participant' do
      let(:headers) { participant.create_new_auth_token }

      it 'returns forbidden' do
        request
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST /v1/user_sessions/:user_session_id/answers (RA fulfillment guard)' do
    let(:team) { create(:team) }
    let(:researcher) { create(:user, :confirmed, :researcher, team_id: team.id) }
    let(:intervention) { create(:intervention, :published, user: researcher) }
    let!(:ra_session) { create(:ra_session, intervention: intervention, autofinish_enabled: true) }
    let(:question_group) { create(:question_group, session: ra_session) }
    let(:question) { create(:question_single, question_group: question_group) }
    let(:participant) { create(:user, :confirmed, :predefined_participant) }
    let(:user_intervention) { create(:user_intervention, user: participant, intervention: intervention) }
    let(:fulfiller) { researcher }
    let!(:ra_user_session) do
      create(:ra_user_session, session: ra_session, user: participant, user_intervention: user_intervention,
                               fulfilled_by: fulfiller, last_answer_at: 1.day.ago)
    end
    let(:user) { fulfiller }
    let(:params) do
      {
        answer: {
          type: 'Answer::Single',
          body: { data: [{ var: 'a1', value: '1' }] }
        },
        question_id: question.id
      }
    end
    let(:request) { post v1_user_session_answers_path(ra_user_session.id), params: params, headers: user.create_new_auth_token }

    shared_examples 'an accepted RA answer' do
      it 'returns created status' do
        expect { request }.to change { ra_user_session.answers.count }.by(1)
        expect(response).to have_http_status(:created)
      end
    end

    shared_examples 'a rejected RA answer' do
      it 'returns forbidden with NOT_RA_FULFILLER and writes nothing' do
        expect { request }.to avoid_changing(Answer, :count).and avoid_changing { ra_user_session.reload.last_answer_at }
        expect(response).to have_http_status(:forbidden)
        expect(json_response['details']).to eq('reason' => 'NOT_RA_FULFILLER')
      end
    end

    context 'when the fulfiller submits an answer' do
      it_behaves_like 'an accepted RA answer'
    end

    context "when the fulfiller is the team admin of the intervention owner's team" do
      let(:fulfiller) { team.team_admin }

      it_behaves_like 'an accepted RA answer'
    end

    context 'when the fulfiller is a collaborator with data access' do
      let(:fulfiller) { create(:user, :confirmed, :researcher) }

      before { create(:collaborator, user: fulfiller, intervention: intervention, data_access: true) }

      it_behaves_like 'an accepted RA answer'
    end

    context 'when a different researcher tries to submit an answer' do
      let(:user) { create(:user, :confirmed, :researcher) }

      it_behaves_like 'a rejected RA answer'
    end

    context 'when the predefined participant who owns the RA session submits an answer' do
      let(:user) { participant }

      it_behaves_like 'a rejected RA answer'
    end
  end
end
