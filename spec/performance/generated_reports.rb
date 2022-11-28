# frozen_string_literal: true

RSpec.describe 'Performance', type: :request do
  context 'Generated reports' do
    let!(:user) { create(:user, :confirmed, :admin) }
    let!(:user_session) { create(:user_session, user: user) }
    let!(:headers) { user.create_new_auth_token }
    let!(:generated_reports_third_party) do
      create_list(:generated_report, 25, :with_pdf_report, :third_party, user_session: user_session)
    end
    let!(:generated_reports_participant) do
      create_list(:generated_report, 25, :with_pdf_report, :participant, user_session: user_session)
    end

    it 'performs index in correct time' do
      expect { get v1_generated_reports_path, headers: headers }
        .to perform_under(0.2).sample(10)
    end
  end
end
