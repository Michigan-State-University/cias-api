# frozen_string_literal: true

RSpec.describe 'POST /v1/interventions/:intervention_id/accesses', type: :request do
  let!(:user) { create(:user, :confirmed, :researcher, created_at: 1.day.ago) }
  let!(:participant) { create(:user, :confirmed, :participant) }
  let!(:intervention) { create(:intervention, status: intervention_status, user_id: user.id) }
  let!(:intervention_status) { :published }
  let!(:session) { create(:session, intervention_id: intervention.id) }
  let!(:participant2) { create(:user, :confirmed, :participant) }
  let!(:emails) { [participant2.email, participant.email] }
  let!(:params) do
    {
      user_session: {
        emails: emails
      }
    }
  end
  let(:request) { post v1_intervention_accesses_path(intervention_id: intervention.id), params: params, headers: user.create_new_auth_token }

  context 'give intervention access' do
    before { request }

    it 'returns correct HTTP status (Created)' do
      expect(response).to have_http_status(:created)
    end

    it 'returns correct response data amount' do
      expect(json_response['data'].size).to eq 2
    end

    it 'returns correct response data' do
      expect(intervention.reload.intervention_accesses.map(&:email)).to match_array emails
    end

    %w[closed archived].each do |status|
      context "when intervention is #{status}" do
        let!(:intervention_status) { status.to_sym }

        before do
          request
        end

        it 'returns correct http status' do
          expect(response).to have_http_status(:not_acceptable)
        end
      end
    end
  end
end
