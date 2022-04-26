# frozen_string_literal: true

RSpec.describe Translations::InterventionJob, type: :job do
  subject { described_class.perform_now(intervention_id, destination_language_id, destination_google_tts_voice_id, user) }

  let!(:user) { create(:user, :confirmed, :researcher) }
  let!(:intervention) { create(:intervention, user: user, status: 'published') }
  let!(:intervention_id) { intervention.id }
  let!(:sessions) { create_list(:session, 10, intervention_id: intervention_id) }

  let_it_be(:destination_language_id) { GoogleLanguage.first.id }
  let_it_be(:destination_google_tts_voice_id) { GoogleTtsVoice.first.id }

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  after do
    subject
  end

  context 'email notifications enabled' do
    it 'send email' do
      expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
    end
  end

  context 'email notifications disabled' do
    let!(:user) { create(:user, :confirmed, :researcher, email_notification: false) }

    it "Don't send email" do
      expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(0)
    end
  end

  context 'creates correct number of session' do
    it 'Has correct number of sessions' do
      subject
      expect(Intervention.order(:created_at).last.sessions_count).to eq(10)
    end
  end
end
