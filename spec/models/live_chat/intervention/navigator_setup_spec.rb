# frozen_string_literal: true

RSpec.describe LiveChat::Intervention::NavigatorSetup, type: :model do
  it { should belong_to(:intervention) }
  it { should have_many(:participant_links) }
  it { should have_one(:phone) }
end
