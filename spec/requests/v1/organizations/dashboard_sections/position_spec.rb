# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/organizations/:organization_id/dashboard_sections/position', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:organization) { create(:organization) }
  let(:reporting_dashboard) {organization.reporting_dashboard}
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
  let(:request) { patch position_v1_organization_dashboard_sections_path(organization_id: organization.id), params: params, headers: user.create_new_auth_token }

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
end
