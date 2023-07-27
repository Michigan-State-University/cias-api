# frozen_string_literal: true

RSpec.describe 'DELETE /v1/live_chat/intervention/:id/navigators/:navigator_id', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:intervention) { create(:intervention, user: admin) }
  let(:navigator) { create(:user, :confirmed, :navigator) }
  let(:headers) { admin.create_new_auth_token }

  let(:request) do
    delete v1_live_chat_intervention_navigator_path(id: intervention.id, navigator_id: navigator.id), headers: headers
  end

  before do
    intervention.navigators << navigator
  end

  context 'Correctly deletes navigators from intervention' do
    it 'returns correct status code (No content)' do
      request
      expect(response).to have_http_status(:no_content)
    end

    it 'Correctly removes navigators' do
      expect { request }.to change { intervention.navigators.reload.count }.by(-1)
    end
  end

  context 'not current editor' do
    let(:intervention) { create(:intervention, :with_collaborators, user: admin, current_editor: create(:user, :researcher, :confirmed)) }

    it {
      request
      expect(response).to have_http_status(:forbidden)
    }
  end

  context 'Incorrect params or intervention' do
    context 'Incorrect IDs' do
      let(:request) do
        delete v1_live_chat_intervention_navigator_path(id: '3322', navigator_id: '90329081'), headers: headers
      end

      it 'returns correct status code (Not found)' do
        request
        expect(response).to have_http_status(:not_found)
      end

      it 'does not change navigators count' do
        expect { request }.not_to change { intervention.navigators.reload.count }
      end
    end
  end

  context 'Conversation archiving' do
    let!(:navigator_conversations) do
      [
        create(:live_chat_conversation, intervention: intervention, live_chat_interlocutors: [LiveChat::Interlocutor.new(user_id: navigator.id)]),
        create(:live_chat_conversation, intervention: intervention, live_chat_interlocutors: [LiveChat::Interlocutor.new(user_id: navigator.id)]),
        create(:live_chat_conversation, intervention: intervention, live_chat_interlocutors: [LiveChat::Interlocutor.new(user_id: navigator.id)])
      ]
    end

    it 'correctly archives all active conversations from navigator' do
      request
      expect(navigator_conversations.each(&:reload).map(&:archived)).to eq [true, true, true]
    end
  end
end
