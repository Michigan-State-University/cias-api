# frozen_string_literal: true

RSpec.describe Tlfb::Event, type: :model do
  it { should belong_to(:day) }
end
