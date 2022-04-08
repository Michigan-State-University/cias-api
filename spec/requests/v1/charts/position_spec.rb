# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/dashboard_section/:dashboard_section/charts/position', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:organization) { create(:organization) }
  let(:reporting_dashboard) { organization.reporting_dashboard }
  let(:dashboard_section) { create(:dashboard_section) }
  let(:chart1) { create(:chart, position: 5, dashboard_section: dashboard_section) }
  let(:chart2) { create(:chart, position: 5, dashboard_section: dashboard_section) }
  let(:chart3) { create(:chart, position: 6, dashboard_section: dashboard_section) }
  let(:params) do
    {
      chart: {
        position: [
          {
            id: chart1.id,
            position: 11
          },
          {
            id: chart2.id,
            position: 22
          },
          {
            id: chart3.id,
            position: 33
          }
        ]
      }
    }
  end
  let(:request) do
    patch position_v1_dashboard_section_charts_path(dashboard_section_id: dashboard_section.id), params: params, headers: user.create_new_auth_token
  end

  context 'when auth' do
    context 'is invalid' do
      let(:request) { patch position_v1_dashboard_section_charts_path(dashboard_section_id: dashboard_section.id), params: params }

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
        positions = json_response['data'].map { |chart| chart['attributes']['position'] }
        expect(positions).to eq [11, 22, 33]
      end
    end
  end
end
