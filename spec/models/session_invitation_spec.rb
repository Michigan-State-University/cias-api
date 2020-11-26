# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SessionInvitation, type: :model do
  describe 'Session' do
    subject { create(:session_invitation) }

    it { should belong_to(:session) }
    it { should be_valid }
  end
end
