# frozen_string_literal: true

class V1::Audio::Regenerate
  attr_reader :question, :block_index, :block, :audio_index, :reflection_index, :language_code, :voice_type

  # rubocop:disable Metrics/ParameterLists
  def self.call(question_id, block_index, audio_index, reflection_index, language_code, voice_type)
    new(question_id, block_index, audio_index, reflection_index, language_code, voice_type).call
  end

  def initialize(question_id, block_index, audio_index, reflection_index, language_code, voice_type)
    @question = Question.find(question_id)
    @block_index = block_index
    @block = question.narrator['blocks'][block_index]
    @audio_index = audio_index
    @reflection_index = reflection_index
    @language_code = language_code
    @voice_type = voice_type
  end
  # rubocop:enable Metrics/ParameterLists

  def call
    audio = Audio.find_by(sha256: digest)
    Audio::TextToSpeech.new(
      audio,
      text: text,
      language: language_code,
      voice_type: voice_type
    ).execute
    audio.save!
    question.narrator['blocks'][block_index] = swap_url_to_block(block, audio.url)
    question.save!
  end

  def correct_block
    return block['reflections']['reflection_index'] if reflection_index

    block
  end

  def text
    correct_block['text'][audio_index].tr(',!.', '').strip.downcase
  end

  def digest
    Digest::SHA256.hexdigest("#{text}_#{language_code}_#{voice_type}")
  end

  def swap_url_to_block(block, url)
    block['reflections']['reflection_index']['audio_urls'][audio_index] = url if reflection_index
    block['audio_urls'][audio_index] = url unless reflection_index
    block
  end
end
