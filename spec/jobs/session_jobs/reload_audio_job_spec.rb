# frozen_string_literal: true

RSpec.describe SessionJobs::ReloadAudio, type: :job do
  let!(:google_tts_voice) { create(:google_tts_voice, language_code: 'pl') }
  let(:session) { create(:session) }

  describe '#perform_later' do
    it 'recreate audio' do
      ActiveJob::Base.queue_adapter = :test
      session.google_tts_voice = google_tts_voice
      session.save
      expect(described_class).to have_been_enqueued
    end
  end
end
