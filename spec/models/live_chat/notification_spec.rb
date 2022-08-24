# frozen_string_literal: true

RSpec.describe LiveChat::Notification, type: :model do
  it { should belong_to(:object) }
  it { should belong_to(:user) }
end
