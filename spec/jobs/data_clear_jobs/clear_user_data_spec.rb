# frozen_string_literal: true

RSpec.describe DataClearJobs::ClearUserData, type: :job do
  subject { described_class.perform_now(intervention.id) }

  let!(:intervention) { create(:intervention, :with_pdf_report, :with_conversations_transcript, user: create(:user, :researcher)) }
  let!(:conversation) { create(:live_chat_conversation, intervention: intervention) }
  let!(:user_intervention1) { create(:user_intervention, intervention: intervention, user: create(:user, :participant, :confirmed)) }
  let!(:user_intervention2) { create(:user_intervention, intervention: intervention, user: create(:user, :guest, :confirmed)) }

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  it 'remove all attachments' do
    expect { subject }.to change(ActiveStorage::Attachment, :count).by(-2)
  end

  it 'interventions return information that hasn\'t have attachments' do
    subject
    expect(intervention.reload.reports.any?).to be false
    expect(intervention.reload.conversations_transcript.attached?).to be false
  end

  it 'remove all user_interventions' do
    expect { subject }.to change(UserIntervention, :count).by(-2)
  end

  it 'remove all quest without any user_intervention' do
    user_id = user_intervention2.user.id
    subject
    expect(User.find_by(id: user_id)).to be nil
  end

  it 'participants are stay intact' do
    user_id = user_intervention1.user.id
    subject
    expect(User.find_by(id: user_id).present?).to be true
  end
end
