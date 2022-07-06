# frozen_string_literal: true

RSpec.describe LiveChat::Interventions::NavigatorInvitations, type: :model do
  it { should belong_to(:intervention) }
end
