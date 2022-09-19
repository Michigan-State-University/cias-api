# frozen_string_literal: true

RSpec.describe V1::Notifications::Message do
  subject { described_class.call(conversation, message) }

  let(:user) { create(:user, :confirmed, :admin) }
  let(:intervention) { create(:intervention, user: user) }

  let!(:navigator) { create(:user, :navigator, :confirmed) }
  let!(:participant) { create(:user, :confirmed, :participant) }
  let!(:interlocutor) { create(:live_chat_interlocutor, user: navigator, conversation: conversation) }
  let!(:interlocutor2) { create(:live_chat_interlocutor, user: participant, conversation: conversation) }
  let!(:conversation) { create(:live_chat_conversation, intervention: intervention) }
  let!(:message) { create(:live_chat_message, conversation: conversation, live_chat_interlocutor: interlocutor) }

  context 'it returns correct data and does not return an error' do
    it { expect { subject }.not_to raise_error }
  end
end
