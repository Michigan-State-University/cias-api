# frozen_string_literal: true

RSpec.describe SessionJob::ReloadAudio, type: :job do
  let(:session) { create(:session) }

  describe '#perform_later' do
    it 'recreate audio' do
      ActiveJob::Base.queue_adapter = :test
      session.google_tts_voice_id = 44
      session.save
      expect(described_class).to have_been_enqueued
    end
  end
end
