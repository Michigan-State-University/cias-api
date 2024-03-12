# frozen_string_literal: true

RSpec.describe 'Performance', type: :request do
  context 'Report templates' do
    let!(:user) { create(:user, :confirmed, :admin) }
    let!(:headers) { user.create_new_auth_token }
    let!(:session) { create(:session) }
    let!(:report_templates) { create_list(:report_template, 20, :with_logo, session: session) }
    let!(:report_template) { create(:report_template, :with_logo, session: session) }

    it 'performs index in correct time' do
      expect { get v1_session_report_templates_path(session_id: session.id), headers: headers }
        .to perform_under(0.2).sample(10)
    end

    it 'performs show in correct time' do
      expect { get v1_session_report_template_path(session_id: session.id, id: report_template.id), headers: headers }
        .to perform_under(0.2).sample(10)
    end
  end
end
