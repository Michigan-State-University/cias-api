# frozen_string_literal: true

RSpec.describe LiveChat::Interventions::NavigatorInvitation, type: :model do
  it { should belong_to(:intervention) }
end
