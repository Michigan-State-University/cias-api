# frozen_string_literal: true

RSpec.describe LiveChat::Interventions::Navigator, type: :model do
  it { should belong_to(:intervention) }
  it { should belong_to(:user) }
end
