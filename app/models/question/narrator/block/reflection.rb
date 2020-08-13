# frozen_string_literal: true

class Question::Narrator::Block::Reflection < Question::Narrator::Block::Interface
  def build
    block['reflections'].each_with_index do |reflection, reflection_index|
      block['reflections'][reflection_index]['audio_urls'] = prepare_urls(reflection)
    end

    block
  end

  private

  def prepare_urls(reflection)
    Question::Narrator::Block::Speech.new(self, index_processing, reflection, reflection_was(reflection)).build['audio_urls']
  end

  def reflection_was(reflection)
    return unless was_reflection_block

    was_reflection_block['reflections'].find do |ref|
      ref['variable'] == reflection['variable'] &&
        ref['value'] == reflection['value']
    end
  end

  def was_reflection_block
    @was_reflection_block ||= question.narrator_was[speech_source].find { |b| reflection?(b) && b['question_id'] == block['question_id'] }
  end
end
