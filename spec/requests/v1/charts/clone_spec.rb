# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/charts/:id/clone', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:chart) do
    create(:chart, :published, name: 'test chart', description: 'test description', formula: {
             payload: 'test1 + test2',
             default_pattern: { color: '#E2B1F4', label: 'Other' },
             patterns: [{ color: '#C766EA', label: 'Label1', match: '=1' }, { color: '#519FA5', label: 'Label2', match: '=2' }]
           })
  end
  let(:headers) { user.create_new_auth_token }
  let(:request) { post v1_clone_chart_path(id: chart.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { post v1_clone_chart_path(id: chart.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when user clones a chart' do
    before { request }

    let(:chart_to_clone) do
      chart.attributes.except('id', 'created_at', 'updated_at')
    end

    let(:chart_cloned) do
      json_response['data']['attributes'].except('id', 'created_at', 'updated_at')
    end

    it { expect(response).to have_http_status(:created) }

    it 'origin and outcome same' do
      expect(chart_to_clone.delete(['status'])).to eq(chart_cloned.delete(['status']))
    end

    it 'sets correct status' do
      expect(chart_cloned['status']).to eq('draft')
    end

    it 'gets a new position value greater than the original one' do
      expect(chart_cloned['position']).to be > chart_to_clone['position']
    end

    it 'gets a new position value unique in its section' do
      expect(Chart.where(dashboard_section_id: chart['dashboard_section_id'], position: chart_cloned['position']).count).to eq(1)
    end
  end
end
