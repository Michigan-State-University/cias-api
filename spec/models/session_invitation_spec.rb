# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Invitation, type: :model do
  describe 'Session invitation' do
    subject { create(:session_invitation) }

    it { should belong_to(:invitable) }
    it { should be_valid }
  end

  describe 'Intervention invitation' do
    subject { create(:intervention_invitation) }

    it { should belong_to(:invitable) }
    it { should be_valid }
  end
end
