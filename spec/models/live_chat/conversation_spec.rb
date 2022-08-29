# frozen_string_literal: true

RSpec.describe LiveChat::Conversation, type: :model do
  it { should have_many(:messages) }
  it { should have_many(:live_chat_interlocutors) }
  it { should have_many(:users) }
  it { should belong_to(:intervention) }
  it { should have_many(:notifications) }
end
