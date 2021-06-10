# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/organizations/:organization_id/sessions/:session_id/invitations', type: :request do
  let!(:user) { create(:user, :confirmed, :admin, created_at: 1.day.ago) }
  let!(:organization) { create(:organization, :with_organization_admin, :with_e_intervention_admin) }
  let!(:health_system) { create(:health_system, name: 'Gotham Health System', organization: organization) }
  let!(:health_clinic1) { create(:health_clinic, name: 'Health Clinic 1', health_system: health_system) }
  let!(:health_clinic2) { create(:health_clinic, name: 'Health Clinic 2', health_system: health_system) }
  let!(:intervention_status) { :published }
  let(:intervention) { create(:intervention, status: intervention_status) }
  let(:session) { create(:session, intervention_id: intervention.id) }
  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      session_invitations:
        [{
          health_clinic_id: health_clinic1.id,
          emails: %w[test1@dom.com test2@com.com]
        },
         {
           health_clinic_id: health_clinic2.id,
           emails: %w[test3@dom.com test4@com.com]
         }]
    }
  end
  let(:request) { post v1_organization_session_invitations_path(organization_id: organization.id, session_id: session.id), headers: headers, params: params }

  context 'when user has permission' do
    context 'when intervention is published' do
      before do
        request
      end

      it 'returns correct http status' do
        expect(response).to have_http_status(:created)
      end

      it 'returns correct response data' do
        expect(json_response['data'].size).to eq(4)
      end

      it 'create correct session invites' do
        expect(session.reload.invitations.map(&:email)).to match_array(%w[test1@dom.com test2@com.com test3@dom.com test4@com.com])
        expect(session.reload.invitations.map(&:health_clinic_id).uniq).to match_array([health_clinic1.id, health_clinic2.id])
      end
    end

    %w[draft closed archived].each do |status|
      context "when intervention is #{status}" do
        let!(:intervention_status) { status.to_sym }

        before do
          request
        end

        it 'returns correct http status' do
          expect(response).to have_http_status(:not_acceptable)
        end
      end
    end
  end
end
