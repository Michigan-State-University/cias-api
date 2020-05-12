# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Intervention, type: :model do
  describe 'Intervention::Single' do
    subject(:intervention_single) { build(:intervention_single) }

    it { should belong_to(:user) }
    it { should have_many(:questions) }
    it { should be_valid }
  end

  describe 'Intervention::Multiple' do
    subject(:intervention_multiple) { build(:intervention_multiple) }

    it { should belong_to(:user) }
    it { should have_many(:questions) }
    it { should be_valid }
  end
end
