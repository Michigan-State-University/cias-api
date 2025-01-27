# frozen_string_literal: true

RSpec.describe V1::Translations::Intervention do
  context 'translate an intervention' do
    subject { described_class.call(intervention, language.id, voice.id) }

    let!(:intervention) { create(:intervention, name: 'Test') }
    let!(:session) { create(:session, intervention: intervention) }

    let(:tts_language) { create(:google_tts_language, :with_voices, language_name: 'French (France)') }
    let(:voice) { tts_language.google_tts_voices.first }
    let(:language) { create(:google_language) }

    context 'params are valid' do
      it 'create copy of the Intervention' do
        expect { subject }.to change(Intervention, :count).by(1)
      end

      it 'set correct google language' do
        expect(subject.google_language_id).to eq(language.id)
      end

      it 'set correct voice' do
        expect(subject.sessions.first.google_tts_voice_id).to eq(voice.id)
      end

      it 'translates session name' do
        session = subject.sessions.first
        expect(session.name).to eq("from=>#{intervention.google_language.language_code} to=>#{language.language_code} text=>#{session.original_text['name']}")
      end
    end

    context 'wrong language id' do
      subject { described_class.call(intervention, nil, voice.id) }

      it 'didn\'t create a Intervention' do
        expect { subject }.to avoid_changing(Intervention, :count)
      end
    end

    context 'voice id is nil' do
      subject { described_class.call(intervention, language.id, nil) }

      let(:first_question) { subject.sessions.first.questions.first }

      it 'create new Intervention' do
        expect { subject }.to change(Intervention, :count).by(1)
      end

      it 'clear audio blocks' do
        expect(first_question.narrator['blocks'].first['audio_urls']).to eq([])
        expect(first_question.narrator['blocks'].first['sha256']).to eq([])
      end
    end
  end
end
