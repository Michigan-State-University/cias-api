# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/live_chat/conversations/:conversation_id/generate_transcript', type: :request do
  let(:researcher) { create(:user, :researcher, :confirmed) }
  let(:intervention) { create(:intervention, :with_navigator_setup, user: researcher) }
  let(:conversation) { create(:live_chat_conversation, intervention: intervention) }
  let(:navigator) { create(:user, :navigator, :confirmed) }
  let(:participant) { create(:user, :participant, :confirmed) }
  let!(:interlocutors) do
    [
      LiveChat::Interlocutor.create!(conversation: conversation, user: navigator),
      LiveChat::Interlocutor.create!(conversation: conversation, user: participant)
    ]
  end
  let(:headers) { researcher.create_new_auth_token }

  let(:request) do
    post v1_live_chat_conversation_generate_transcript_path(conversation_id: conversation.id), headers: headers
  end

  before_all { ActiveJob::Base.queue_adapter = :test }

  before { request }

  context 'When conversation is not archived' do
    it 'returns correct status code (OK)' do
      expect(response).to have_http_status(:created)
    end
  end

  context 'When conversation is archived' do
    let(:conversation) { create(:live_chat_conversation, intervention: intervention, archived: true) }

    it 'correctly generates csv the first time' do
      expect(response).to have_http_status(:created)
    end

    context 'returns correct HTTP status code (Method Not Allowed) when generating transcript for the second time' do
      let(:conversation) do
        create(:live_chat_conversation, intervention: intervention, archived: true,
                                        transcript: FactoryHelpers.upload_file('spec/factories/csv/test_empty.csv', 'text/csv', false))
      end

      it do
        expect(response).to have_http_status(:method_not_allowed)
      end
    end
  end
end
