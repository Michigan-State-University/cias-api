# frozen_string_literal: true

RSpec.describe 'POST /v1/live_chat/conversations', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:intervention) { create(:intervention, user: user) }
  let(:params) do
    {
      conversation: {
        user_ids: [user.id, participant.id],
        intervention_id: intervention.id
      }
    }
  end

  let(:request) do
    post v1_live_chat_conversations_path, params: params, headers: user.create_new_auth_token
  end

  before { request }

  it 'returns correct status code (OK)' do
    expect(response).to have_http_status(:ok)
  end

  it 'returns correct conversation data (with 2 interlocutors)' do
    expect(json_response['data']['relationships']['live_chat_interlocutors']['data'].size).to eq 2
  end

  context 'when user don\'t have permission' do
    let(:user) { create(:user, :health_clinic_admin, :confirmed) }

    it { expect(response).to have_http_status(:forbidden) }
  end
end
