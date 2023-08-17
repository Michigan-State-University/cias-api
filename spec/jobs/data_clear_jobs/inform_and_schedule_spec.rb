# frozen_string_literal: true

RSpec.describe DataClearJobs::InformAndSchedule, type: :job do
  subject { described_class.perform_now(intervention.id) }

  let!(:intervention) { create(:intervention, :with_pdf_report, :with_conversations_transcript, user: create(:user, :researcher)) }
  let!(:conversation) { create(:live_chat_conversation, intervention: intervention) }
  let!(:user_intervention1) { create(:user_intervention, intervention: intervention, user: create(:user, :participant, :confirmed)) }
  let!(:user_intervention2) { create(:user_intervention, intervention: intervention, user: create(:user, :guest, :confirmed)) }

  before do
    ActiveJob::Base.queue_adapter = :test
  end
end
