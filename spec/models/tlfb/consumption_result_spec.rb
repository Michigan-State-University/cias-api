# frozen_string_literal: true

RSpec.describe Tlfb::ConsumptionResult, type: :model do
  it { should belong_to(:day) }
end
