# frozen_string_literal: true

RSpec.describe LiveChat::Interventions::NavigatorSetup, type: :model do
  it { should belong_to(:intervention) }
  it { should have_many(:participant_links) }
  it { should have_one(:phone) }
  it { should have_many_attached(:participant_files) }
  it { should have_many_attached(:navigator_files) }
  it { should have_one_attached(:filled_script_template) }
end
