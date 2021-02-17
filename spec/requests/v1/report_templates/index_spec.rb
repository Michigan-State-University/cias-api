# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/sessions/:session_id/report_templates', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }
  let!(:session) { create :session }

  let!(:report_template1) { create(:report_template, :with_logo, session: session) }
  let!(:report_template2) { create(:report_template, :with_logo, session: session) }

  before do
    get v1_session_report_templates_path(session_id: session.id), headers: headers
  end

  context 'when there are report templates' do
    it 'has correct http code :ok' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns list of report templates for a session' do
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
      ).and include(
        'id' => report_template2.id.to_s,
        'type' => 'report_template',
        'attributes' => include(
          'name' => report_template2.name,
          'report_for' => report_template2.report_for,
          'summary' => report_template2.summary,
          'logo_url' => include(report_template2.logo.name),
          'session_id' => session.id
        )
      )
    end
  end

  context 'when there are no report templates' do
    before do
      session.report_templates.destroy_all
      get v1_session_report_templates_path(session_id: session.id), headers: headers
    end

    it 'has correct http code :ok' do
      expect(response).to have_http_status(:ok)
    end

    it 'response should be empty' do
      expect(json_response['data']).to be_empty
    end
  end
end
