# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Problem, type: :model do
  describe 'Problem' do
    subject { create(:problem) }

    it { should belong_to(:user) }
    it { should have_many(:interventions) }
    it { should be_valid }
  end
end
