# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/organizations/:organization_id/dashboard_sections/position', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:organization) { create(:organization) }
  let(:reporting_dashboard) { organization.reporting_dashboard }
  let(:dashboard_section1) { create(:dashboard_section, position: 4, reporting_dashboard: reporting_dashboard) }
  let(:dashboard_section2) { create(:dashboard_section, position: 5, reporting_dashboard: reporting_dashboard) }
  let(:dashboard_section3) { create(:dashboard_section, position: 6, reporting_dashboard: reporting_dashboard) }
  let(:params) do
    {
      dashboard_section: {
        position: [
          {
            id: dashboard_section1.id,
            position: 11
          },
          {
            id: dashboard_section2.id,
            position: 22
          },
          {
            id: dashboard_section3.id,
            position: 33
          }
        ]
      }
    }
  end
  let(:request) do
    patch position_v1_organization_dashboard_sections_path(organization_id: organization.id), params: params, headers: user.create_new_auth_token
  end

  context 'when auth' do
    context 'is invalid' do
      let(:request) { patch position_v1_organization_dashboard_sections_path(organization_id: organization.id), params: params }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when response' do
    context 'is JSON' do
      before { request }

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'contains' do
      before { request }

      it 'to hash success' do
        expect(json_response.class).to be(Hash)
      end

      it 'proper order' do
        positions = json_response['data'].map { |dashboard_section| dashboard_section['attributes']['position'] }
        expect(positions).to eq [11, 22, 33]
      end
    end
  end

  context 'when an e-intervention admin of the organization reorders' do
    let(:organization) { create(:organization, :with_e_intervention_admin) }
    let(:user) { organization.e_intervention_admins.first }

    before { request }

    it { expect(response).to have_http_status(:ok) }
    it { expect(dashboard_section1.reload.position).to eq 11 }
  end

  context 'when an e-intervention admin of another organization reorders' do
    let(:user) { create(:organization, :with_e_intervention_admin).e_intervention_admins.first }

    before { request }

    it { expect(response).to have_http_status(:forbidden) }
    it { expect(dashboard_section1.reload.position).to eq 4 }
  end

  context 'when a section of another organization is in the list' do
    let(:other_section) { create(:dashboard_section, position: 9) }
    let(:params) do
      { dashboard_section: { position: [{ id: dashboard_section1.id, position: 11 }, { id: other_section.id, position: 1 }] } }
    end

    before { request }

    it { expect(response).to have_http_status(:not_found) }

    it 'does not change positions' do
      expect([dashboard_section1.reload.position, other_section.reload.position]).to eq [4, 9]
    end
  end

  context 'when a position is not a whole number' do
    let(:params) { { dashboard_section: { position: [{ id: dashboard_section1.id, position: 'abc' }] } } }

    before { request }

    it { expect(response).to have_http_status(:unprocessable_content) }
    it { expect(dashboard_section1.reload.position).to eq 4 }
  end

  context 'when the caller can see the organization but cannot update its dashboard' do
    let(:health_system) { create(:health_system, organization: organization) }
    let(:user) do
      create(:user, :confirmed, roles: %w[e_intervention_admin health_system_admin], organizable: health_system).tap do |caller|
        OrganizationInvitation.create!(user: caller, organization: create(:organization), accepted_at: Time.current)
      end
    end

    before { request }

    it { expect(response).to have_http_status(:forbidden) }
    it { expect(dashboard_section1.reload.position).to eq 4 }
  end
end
