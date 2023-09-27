# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH  /v1/report_templates/sections/:section_id/move_variants', type: :request do
  let(:request) { patch v1_report_template_section_move_variants_path(report_template_section.id), params: params, headers: headers }
  let(:user) { create(:user, :researcher, :confirmed) }
  let(:headers) { user.create_new_auth_token }
  let(:intervention) { create(:intervention, user: user) }
  let(:report_template_section) do
    create(:report_template_section, report_template: create(:report_template, session: create(:session, intervention: intervention)))
  end
  let!(:report_template_section_variant1) { create(:report_template_section_variant, report_template_section: report_template_section, position: 0) }
  let!(:report_template_section_variant2) { create(:report_template_section_variant, report_template_section: report_template_section, position: 2) }
  let(:params) do
    {
      variant: {
        position: [
          { id: report_template_section_variant1.id, position: 1 },
          { id: report_template_section_variant2.id, position: 0 }
        ]
      }
    }
  end

  before { request }

  context 'when params are correct' do
    it 'return correct status' do
      expect(response).to have_http_status(:ok)
    end

    it 'correctly reorders variants' do
      expected = report_template_section.variants.map(&:reload).sort_by(&:position).pluck(:id)
      expect(json_response['data'].pluck('id')).to eq expected
    end
  end

  context 'when params invalid (wrong ID)' do
    let(:params) do
      {
        variant: {
          position: [
            { id: 'invalid-id', position: 1 },
            { id: 'id2', position: 2 }
          ]
        }
      }
    end

    it 'returns Not Found HTTP status code' do
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when params invalid (wrong request format)' do
    let(:params) do
      {
        position: []
      }
    end

    it 'returns Bad Request HTTP status code' do
      expect(response).to have_http_status(:bad_request)
    end
  end

  context 'when current user is the researcher who has not access to do this' do
    let(:headers) { create(:user, :researcher, :confirmed).create_new_auth_token }

    it 'returns Bad Request HTTP status code' do
      expect(response).to have_http_status(:forbidden)
    end
  end

  it_behaves_like 'correct behavior for the intervention with collaborators'
end
