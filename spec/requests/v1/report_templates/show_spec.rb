# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/sessions/:session_id/report_template/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }
  let!(:session) { create :session }

  let!(:report_template1) { create(:report_template, :with_logo, session: session) }

  before do
    get v1_session_report_template_path(session_id: session.id, id: report_template1.id),
        headers: headers
  end

  context 'when there is report template' do
    it 'has correct http code :ok' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns report template' do
      expect(json_response['data']).to include(
        'id' => report_template1.id.to_s,
        'type' => 'report_template',
        'attributes' => include(
          'name' => report_template1.name,
          'report_for' => report_template1.report_for,
          'summary' => report_template1.summary,
          'logo_url' => include(report_template1.logo.name),
          'session_id' => session.id
        )
      )
    end
  end

  context 'when there is no team with given id' do
    before do
      get v1_team_path(id: 'non-existing-id'), headers: headers
    end

    it 'has correct http code :not_found' do
      expect(response).to have_http_status(:not_found)
    end
  end
end
