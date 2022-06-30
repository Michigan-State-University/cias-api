# frozen_string_literal: true

RSpec.describe LiveChat::Interventions::ParticipantLink, type: :model do
  it { should belong_to(:navigator_setup) }
end
