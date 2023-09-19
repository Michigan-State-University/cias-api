# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/interventions/:intervention_id/invitations', type: :request do
  let!(:user) { create(:user, :confirmed, :admin, created_at: 1.day.ago) }
  let!(:organization) { create(:organization, :with_organization_admin, :with_e_intervention_admin) }
  let!(:health_system) { create(:health_system, name: 'Gotham Health System', organization: organization) }
  let!(:health_clinic1) { create(:health_clinic, name: 'Health Clinic 1', health_system: health_system) }
  let!(:health_clinic2) { create(:health_clinic, name: 'Health Clinic 2', health_system: health_system) }
  let(:intervention) { create(:intervention, :published) }
  let(:session) { create(:session, intervention: intervention) }

  let(:headers) { user.create_new_auth_token }
  let(:request) do
    get v1_intervention_invitations_path(intervention_id: intervention.id), headers: headers
  end

  context 'session invitations' do
    let!(:session_invitations1) do
      create_list(:session_invitation, 3, health_clinic_id: health_clinic1.id, invitable_id: session.id,
                                          invitable_type: 'Session')
    end
    let!(:session_invitations2) do
      create_list(:session_invitation, 2, health_clinic_id: health_clinic2.id, invitable_id: session.id,
                                          invitable_type: 'Session')
    end

    before do
      request
    end

    it 'return correct http code' do
      expect(response).to have_http_status(:ok)
    end

    it 'return correct data size' do
      expect(json_response['data'].size).to eq(5)
    end

    it 'return correct keys' do
      expect(json_response['data'][0]['attributes'].keys).to match_array(%w[email health_clinic_id target_id])
    end

    context 'when current user doesn\'t have access' do
      let(:headers) { create(:user, :participant).create_new_auth_token }

      it 'return correct http code' do
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  context 'intervention invitations' do
    let(:intervention) { create(:flexible_order_intervention, :published) }

    let!(:intervention_invitations) do
      create_list(:intervention_invitation, 3, invitable_id: intervention.id,
                                               invitable_type: 'Intervention')
    end

    before do
      request
    end

    it 'return correct http code' do
      expect(response).to have_http_status(:ok)
    end

    it 'return correct data size' do
      expect(json_response['data'].size).to eq(3)
    end
  end
end
