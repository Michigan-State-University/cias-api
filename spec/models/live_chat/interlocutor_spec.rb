# frozen_string_literal: true

RSpec.describe LiveChat::Interlocutor, type: :model do
  it { should belong_to(:user) }
  it { should belong_to(:conversation) }
end
