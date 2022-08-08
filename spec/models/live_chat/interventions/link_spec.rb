# frozen_string_literal: true

RSpec.describe LiveChat::Interventions::Link, type: :model do
  it { should belong_to(:navigator_setup) }
end
