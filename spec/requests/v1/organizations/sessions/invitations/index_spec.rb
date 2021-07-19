# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/organizations/:organization_id/sessions/:session_id/invitations', type: :request do
  let!(:user) { create(:user, :confirmed, :admin, created_at: 1.day.ago) }
  let!(:organization) { create(:organization, :with_organization_admin, :with_e_intervention_admin) }
  let!(:health_system) { create(:health_system, name: 'Gotham Health System', organization: organization) }
  let!(:health_clinic1) { create(:health_clinic, name: 'Health Clinic 1', health_system: health_system) }
  let!(:health_clinic2) { create(:health_clinic, name: 'Health Clinic 2', health_system: health_system) }
  let!(:intervention_status) { :published }
  let(:intervention) { create(:intervention, status: intervention_status) }
  let(:session) { create(:session, intervention_id: intervention.id) }
  let!(:session_invitations1) do
    create_list(:session_invitation, 3, health_clinic_id: health_clinic1.id, invitable_id: session.id,
                                        invitable_type: 'Session')
  end
  let!(:session_invitations2) do
    create_list(:session_invitation, 2, health_clinic_id: health_clinic2.id, invitable_id: session.id,
                                        invitable_type: 'Session')
  end

  let(:headers) { user.create_new_auth_token }
  let(:request) do
    get v1_organization_session_invitations_path(organization_id: organization.id, session_id: session.id),
        headers: headers
  end

  context 'will retrieve all associated session invitations' do
    before do
      request
    end

    it 'return correct http code' do
      expect(response).to have_http_status(:ok)
    end

    it 'return correct data size' do
      expect(json_response['data'].size).to eq(5)
    end
  end
end
