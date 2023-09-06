# frozen_string_literal: true

RSpec.describe DataClearJobs::ClearUserData, type: :job do
  subject { described_class.perform_now(intervention.id) }

  let!(:intervention) { create(:intervention, :with_pdf_report, :with_conversations_transcript, user: create(:user, :researcher)) }
  let!(:conversation) { create(:live_chat_conversation, intervention: intervention) }
  let!(:user_intervention1) { create(:user_intervention, intervention: intervention, user: create(:user, :participant, :confirmed)) }
  let!(:user_intervention2) { create(:user_intervention, intervention: intervention, user: create(:user, :guest, :confirmed)) }
  let!(:user_intervention3) { create(:user_intervention, intervention: intervention, user: create(:user, :confirmed, roles: ['predefined_participant'])) }
  let!(:predefined_user_parameter) { PredefinedUserParameter.create!(user_id: user_intervention3.user_id, intervention_id: user_intervention3.intervention_id) }

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  it 'remove all attachments' do
    expect { subject }.to change(ActiveStorage::Attachment, :count).by(-2)
  end

  it 'create a notification' do
    expect { subject }.to change(Notification, :count).by(1)
  end

  it 'interventions return information that hasn\'t have attachments' do
    subject
    expect(intervention.reload.reports.any?).to be false
    expect(intervention.reload.conversations_transcript.attached?).to be false
  end

  it 'remove all user_interventions' do
    expect { subject }.to change(UserIntervention, :count).by(-3)
  end

  it 'remove all guests without any user_intervention' do
    user_id = user_intervention2.user.id
    subject
    expect(User.find_by(id: user_id)).to be nil
  end

  it 'remove all predefined participants without any user_intervention' do
    user_id = user_intervention3.user.id
    subject
    expect(User.find_by(id: user_id)).to be nil
  end

  it 'removes associated predefined user parameters' do
    expect { subject }.to change(PredefinedUserParameter, :count).by(-1)
  end

  it 'participants are stay intact' do
    user_id = user_intervention1.user.id
    subject
    expect(User.find_by(id: user_id).present?).to be true
  end
end
