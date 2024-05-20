# frozen_string_literal: true

class V1::Audio::Regenerate
  attr_reader :question, :block_index, :block, :audio_index, :reflection_index, :language_code, :voice_type

  def self.call(regenerate_params, language_code, voice_type)
    new(regenerate_params, language_code, voice_type).call
  end

  def initialize(regenerate_params, language_code, voice_type)
    @question = Question.find(regenerate_params[:question_id])
    @block_index = regenerate_params[:block_index]
    @block = question.narrator['blocks'][@block_index]
    @audio_index = regenerate_params[:audio_index]
    @reflection_index = regenerate_params[:reflection_index]
    @language_code = language_code
    @voice_type = voice_type
  end

  def call
    audio = V1::AudioService.call(text, preview: true, language_code: language_code, voice_type: voice_type)
    if audio&.url == block_audio_url
      Audio::TextToSpeech.new(
        audio,
        text: text,
        language: language_code,
        voice_type: voice_type
      ).execute
      audio.save!
    end
    question.narrator['blocks'][block_index] = swap_url_to_block(block, audio.url)
    question.save!
  end

  def correct_block
    return block['reflections'][reflection_index] if reflection_index

    block
  end

  def text
    correct_block['text'][audio_index].tr(',!.', '').strip.downcase
  end

  def digest
    Digest::SHA256.hexdigest("#{text}_#{language_code}_#{voice_type}")
  end

  def swap_url_to_block(block, url)
    block['reflections'][reflection_index]['audio_urls'][audio_index] = url if reflection_index
    block['audio_urls'][audio_index] = url unless reflection_index
    block
  end

  def block_audio_url
    return block['reflections'][reflection_index]['audio_urls'][audio_index] if reflection_index

    block['audio_urls'][audio_index]
  end
end
