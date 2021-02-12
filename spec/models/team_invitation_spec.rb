# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TeamInvitation, type: :model do
  it { should belong_to(:user) }
  it { should belong_to(:team) }

  describe '#not_accepted' do
    let!(:accepted_team_invitation) { create(:team_invitation, :accepted) }
    let!(:not_accepted_team_invitation) { create(:team_invitation) }

    it 'return only not accepted team invitations' do
      expect(described_class.not_accepted).to include(not_accepted_team_invitation).and \
        not_include(accepted_team_invitation)
    end
  end

  describe '#unique_invitation' do
    context 'not accepted invitation is unique' do
      let!(:accepted_team_invitation) { create(:team_invitation, :accepted) }
      let(:team_invitation) do
        build_stubbed(
          :team_invitation,
          user_id: accepted_team_invitation.user_id,
          team_id: accepted_team_invitation.team_id
        )
      end

      it 'team invitation is valid' do
        expect(team_invitation).to be_valid
      end
    end

    context 'not accepted invitation already exists' do
      let!(:not_accepted_team_invitation) { create(:team_invitation) }
      let(:team_invitation) do
        build_stubbed(
          :team_invitation,
          user_id: not_accepted_team_invitation.user_id,
          team_id: not_accepted_team_invitation.team_id
        )
      end

      it 'team invitation is invalid on create' do
        expect(team_invitation.valid?(:create)).to eq(false)
        expect(team_invitation.errors.messages[:user_id]).to include(/already exists/)
      end

      it 'team invitation valid on update' do
        expect(team_invitation.valid?(:update)).to eq(true)
        expect(not_accepted_team_invitation.valid?(:update)).to eq(true)
      end
    end
  end
end
