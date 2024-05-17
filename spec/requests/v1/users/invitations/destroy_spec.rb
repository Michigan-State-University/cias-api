# frozen_string_literal: true

require 'rails_helper'

describe 'DELETE /v1/users/invitations', type: :request do
  let(:request) { delete v1_invitation_path(user_with_pending_invitation), headers: headers }

  let!(:user_with_pending_invitation) { create(:user, email: 'test@example.com', invitation_token: 'EXAMPLE_TOKEN', invitation_accepted_at: nil) }

  %w[guest participant researcher e_intervention_admin team_admin organization_admin health_system_admin health_clinic_admin third_party].each do |role|
    context "when authenticated as #{role}" do
      let(:current_user) { create(:user, role) }
      let(:headers) { current_user.create_new_auth_token }

      it 'returns not_found status' do
        request

        expect(response).to have_http_status(:not_found)
        expect(user_with_pending_invitation.reload.invitation_token).to eq 'EXAMPLE_TOKEN'
      end
    end
  end

  context 'when authenticated as admin user' do
    let(:admin_user) { create(:user, :admin) }
    let(:headers)    { admin_user.create_new_auth_token }

    it 'returns no_content status' do
      request

      expect(response).to have_http_status(:no_content)
      expect(User.find_by(email: 'test@example.com')).to be_nil
    end
  end
end
