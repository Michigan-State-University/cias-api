# frozen_string_literal: true

RSpec.describe DataClearJobs::DeleteUserReports, type: :job do
  subject { described_class.perform_now(intervention.id) }

  let!(:intervention) { create(:intervention, :with_pdf_report, :with_conversations_transcript, user: create(:user, :researcher)) }
  let!(:session) { create(:session, intervention: intervention) }
  let!(:user_session) { create(:user_session, session: session) }
  let!(:generated_report) { create(:generated_report, user_session: user_session) }

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  it 'remove all attachments' do
    expect { subject }.to change(GeneratedReport, :count).by(-1)
  end
end
