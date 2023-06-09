# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrganizableMailer, type: :mailer do
  describe 'invite_user' do
    let!(:organization_admin) { create(:user, :confirmed, :organization_admin) }
    let!(:organization) { create(:organization, name: 'Michigan Public Health') }
    let!(:invitation) { create(:organization_invitation, user: organization_admin, organization: organization) }
    let!(:email) { 'example@gmail.com' }
    let!(:organization_type) { 'Organization' }

    let(:mail) do
      described_class.invite_user(invitation_token: invitation.invitation_token,
                                  email: email,
                                  organizable: organization,
                                  organizable_type: organization_type)
    end

    it 'renders the headers' do
      expect(mail.subject).to eq("You've been invited to the Organization")
      expect(mail.to).to eq(['example@gmail.com'])
    end
  end
end
