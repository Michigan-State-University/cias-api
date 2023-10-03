# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/interventions/:intervention_id/invitations/:id', type: :request do
  let!(:user) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, :published, user: user) }
  let(:session) { create(:session, intervention: intervention) }
  let!(:invitation) do
    create(:session_invitation, invitable_id: session.id, invitable_type: 'Session')
  end

  let(:headers) { user.create_new_auth_token }
  let(:request) do
    delete v1_intervention_invitation_path(intervention_id: intervention.id, id: invitation.id), headers: headers
  end

  it 'removed invitation' do
    expect { request }.to change(Invitation, :count).by(-1)
  end

  it 'return correct http code' do
    request
    expect(response).to have_http_status(:no_content)
  end

  context 'other researcher' do
    let(:headers) { create(:user, :confirmed, :researcher).create_new_auth_token }

    it 'return correct http code' do
      request
      expect(response).to have_http_status(:not_found)
    end
  end
end
