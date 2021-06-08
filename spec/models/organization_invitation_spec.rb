# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrganizationInvitation, type: :model do
  it { should belong_to(:user) }
  it { should belong_to(:organization) }

  describe '#not_accepted' do
    let!(:accepted_organization_invitation) { create(:organization_invitation, :accepted) }
    let!(:not_accepted_organization_invitation) { create(:organization_invitation) }

    it 'return only not accepted organization invitations' do
      expect(described_class.not_accepted).to include(not_accepted_organization_invitation).and \
        not_include(accepted_organization_invitation)
    end
  end

  describe '#unique_invitation' do
    context 'not accepted invitation is unique' do
      let!(:accepted_organization_invitation) { create(:organization_invitation, :accepted) }
      let(:organization_invitation) do
        build_stubbed(
          :organization_invitation,
          user_id: accepted_organization_invitation.user_id,
          organization_id: accepted_organization_invitation.organization_id
        )
      end

      it 'organization invitation is valid' do
        expect(organization_invitation).to be_valid
      end
    end

    context 'not accepted invitation already exists' do
      let!(:not_accepted_organization_invitation) { create(:organization_invitation) }
      let(:organization_invitation) do
        build_stubbed(
          :organization_invitation,
          user_id: not_accepted_organization_invitation.user_id,
          organization_id: not_accepted_organization_invitation.organization_id
        )
      end

      it 'organization invitation is invalid on create' do
        expect(organization_invitation.valid?(:create)).to eq(false)
        expect(organization_invitation.errors.messages[:user_id]).to include('already exists')
      end

      it 'organization invitation valid on update' do
        expect(organization_invitation.valid?(:update)).to eq(true)
        expect(not_accepted_organization_invitation.valid?(:update)).to eq(true)
      end
    end
  end
end
