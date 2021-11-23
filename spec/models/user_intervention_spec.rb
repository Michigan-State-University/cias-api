# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserIntervention, type: :model do
  context 'UserIntervention' do
    subject { create(:user_intervention) }

    it { should belong_to(:user) }
    it { should belong_to(:intervention) }
    it { should have_many(:user_sessions) }
  end
end
