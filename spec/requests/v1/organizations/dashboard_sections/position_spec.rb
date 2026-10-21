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

  context 'when a position is an SQL expression' do
    let(:params) { { dashboard_section: { position: [{ id: dashboard_section1.id, position: '1+1+5' }] } } }

    before { request }

    it 'does not evaluate the expression' do
      pending 'BUG: the bulk position update interpolates position values into raw SQL, so "1+1+5" is evaluated and stored as 7 (T-02)'
      expect(response.status).to be_between(400, 499)
      expect(dashboard_section1.reload.position).to eq 4
    end
  end

  context 'when an e-intervention admin of the organization sends a section of another organization' do
    let(:organization) { create(:organization, :with_e_intervention_admin) }
    let(:user) { organization.e_intervention_admins.first }
    let(:other_organization) { create(:organization) }
    let(:foreign_section) do
      create(:dashboard_section, position: 1, reporting_dashboard: other_organization.reporting_dashboard)
    end
    let(:params) { { dashboard_section: { position: [{ id: foreign_section.id, position: 42 }] } } }

    before { request }

    it 'does not move it' do
      pending 'BUG: the bulk position update changes rows by id without scoping them to the organization in the URL (T-53)'
      expect(foreign_section.reload.position).to eq 1
    end
  end
end
