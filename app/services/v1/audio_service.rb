# frozen_string_literal: true

class V1::AudioService
  attr_reader :text, :language_code, :voice_type, :preview_audio

  def self.call(text, preview: false, language_code: nil, voice_type: nil)
    new(text, preview: preview, language_code: language_code, voice_type: voice_type).call
  end

  def initialize(text, preview: false, language_code: nil, voice_type: nil)
    @text = unify_text(text)
    @language_code = language_code || ENV.fetch('TEXT_TO_SPEECH_LANGUAGE', 'en-US')
    @voice_type = voice_type || ENV.fetch('TEXT_TO_SPEECH_VOICE', 'en-US-Standard-C')
    @preview_audio = preview
  end

  def call
    return if text.blank?

    digest = prepare_audio_digest
    Audio.find_by(sha256: digest) || create_audio(digest)
  end

  def prepare_audio_digest
    Digest::SHA256.hexdigest("#{text}_#{language_code}_#{voice_type}")
  end

  private

  # Synthesize the speech BEFORE opening any DB transaction (so the external TTS call never
  # holds a connection/lock open), then persist the row and its mp3 atomically.
  #
  # create_or_find_by! leans on the DB unique index instead of a check-then-act find: two
  # requests racing to build the same (text, language, voice) digest converge on a single
  # row instead of the loser raising ActiveRecord::RecordNotUnique.
  # See .claude/jira-tasks/backlog/audio-tts-find-or-create-race.
  def create_audio(digest)
    speech = Audio::TextToSpeech.new(Audio.new, text: text, language: language_code, voice_type: voice_type)
    content = speech.fetch_speech_from_text

    audio = Audio.create_or_find_by!(sha256: digest) do |new_audio|
      new_audio.language = language_code
      new_audio.voice_type = voice_type
      new_audio.usage_counter = 0 if preview_audio
      attach_mp3(new_audio, content)
    end

    audio.reload
  end

  def attach_mp3(audio, content)
    audio.mp3.attach(io: StringIO.new(content), filename: "#{audio.sha256}.mp3", content_type: 'audio/mpeg')
  end

  def unify_text(text)
    text.tr('¿,!.', '').strip.downcase
  end
end
