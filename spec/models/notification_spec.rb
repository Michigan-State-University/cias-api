# frozen_string_literal: true

RSpec.describe Notification, type: :model do
  it { should belong_to(:notifiable) }
  it { should belong_to(:user) }
end
