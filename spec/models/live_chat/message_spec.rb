# frozen_string_literal: true

RSpec.describe LiveChat::Message, type: :model do
  it { should belong_to(:conversation) }
  it { should belong_to(:live_chat_interlocutor) }
  it { should delegate_method(:user).to :live_chat_interlocutor }
end
