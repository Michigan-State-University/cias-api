# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InterventionInvitation, type: :model do
  describe 'Intervention' do
    subject { create(:intervention_invitation) }

    it { should belong_to(:intervention) }
    it { should be_valid }
  end
end
