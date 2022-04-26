# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/report_templates/:report_template_id/move_sections', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }
  let!(:session) { create(:session) }
  let!(:report_template) { create(:report_template, session: session) }
  let!(:report_template_section1) { create(:report_template_section, report_template: report_template, position: 0) }
  let!(:report_template_section2) { create(:report_template_section, report_template: report_template, position: 1) }
  let!(:report_template_section3) { create(:report_template_section, report_template: report_template, position: 2) }
  let!(:params) do
    {
      'section' => {
        'position' => [
          { 'id' => report_template_section2.id, 'position' => 2 },
          { 'id' => report_template_section3.id, 'position' => 1 }
        ]
      }
    }
  end

  before do
    patch v1_report_template_move_sections_path(report_template_id: report_template.id),
          params: params, headers: headers
  end

  context 'user has permission and params are valid' do
    it 'return correct status' do
      expect(response).to have_http_status(:ok)
    end

    it 'return sections in correct position' do
      expect(json_response['included'].map do |section|
               section['id']
             end).to eql([report_template_section1.id, report_template_section3.id, report_template_section2.id])
    end
  end

  context 'user has permission and params are invalid' do
    let!(:params) do
      {
        'section' => {
          'position' => [
            { 'id' => 'wrong_id', 'position' => 2 },
            { 'id' => report_template_section3.id, 'position' => 1 }
          ]
        }
      }
    end

    it 'return correct status' do
      expect(response).to have_http_status(:not_found)
    end

    it 'response contains proper error message' do
      expect(json_response['message']).to include "Couldn't find ReportTemplate::Section with"
    end
  end

  context 'when user has not permision' do
    let(:user) { create(:user, :confirmed, :researcher) }
    let(:headers) { user.create_new_auth_token }

    it 'return correct status' do
      expect(response).to have_http_status(:forbidden)
    end

    it 'return correct message' do
      expect(json_response['message']).to eql('You are not authorized to access this page.')
    end
  end
end
