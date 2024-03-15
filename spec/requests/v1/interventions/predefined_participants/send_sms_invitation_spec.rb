# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:intervention_id/predefined_participants/:id/sms_send_invitation', type: :request do
  let!(:intervention) { create(:intervention, :with_predefined_participants, user: researcher) }
  let(:researcher) { create(:user, :researcher, :confirmed) }
  let(:user) { intervention.predefined_users.first }
  let(:user_id) { user.id }
  let(:current_user) { researcher }
  let(:request) do
    post send_sms_invitation_v1_intervention_predefined_participant_path(intervention_id: intervention.id, id: user_id),
         headers: current_user.create_new_auth_token
  end

  before do
    allow_any_instance_of(Communication::Sms).to receive(:send_message).and_return(true)
  end

  it 'return correct body' do
    request
    expect(json_response['invitation_sent_at']).to be_nil
  end

  it 'skip creation of message' do
    expect { request }.not_to change(Message, :count)
  end

  context 'when user has assigned phone' do
    before do
      user.create_phone(iso: 'PL', prefix: '+48', number: '777777777')
    end

    it 'return correct status' do
      request
      expect(response).to have_http_status(:ok)
    end

    it 'return correct body' do
      request
      expect(json_response['sms_invitation_sent_at']).to be_present
    end

    it 'skip creation of message' do
      expect { request }.to change(Message, :count).by(1)
    end
  end

  context 'when id is wrong' do
    let(:user_id) { 'wrongId' }

    it 'return correct status' do
      request
      expect(response).to have_http_status(:not_found)
    end
  end

  it_behaves_like 'users without access'
end
