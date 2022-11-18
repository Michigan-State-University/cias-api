# frozen_string_literal: true

RSpec.describe V1::Notifications::TranscriptReady do
  subject { described_class.call(object, user, name) }

  describe 'Intervention' do
    let(:user) { create(:user, :confirmed, :researcher) }
    let(:object) { create(:intervention, live_chat_enabled: true, user: user) }
    let(:name) { object.name }

    it 'correctly creates notification with valid data' do
      expect { subject }.to change(Notification, :count).by(1)
      expect(Notification.first.event).to eq :intervention_conversations_transcript_ready.to_s
      expect(Notification.first.data).to include(
        'intervention_id' => object.id,
        'intervention_name' => name,
        'transcript' => nil
      )
    end
  end

  describe 'Conversation' do
    let(:user) { create(:user, :confirmed, :navigator) }
    let(:intervention) { create(:intervention, live_chat_enabled: true) }
    let(:object) { create(:live_chat_conversation, intervention: intervention) }
    let(:name) { intervention.name }

    it 'correctly creates notification with valid data' do
      expect { subject }.to change(Notification, :count).by(1)
      expect(Notification.first.event).to eq :conversation_transcript_ready.to_s
      expect(Notification.first.data).to include(
        'conversation_id' => object.id,
        'intervention_name' => name,
        'transcript' => nil,
        'archived' => false
      )
    end
  end
end
