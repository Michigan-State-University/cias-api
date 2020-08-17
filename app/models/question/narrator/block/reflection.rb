# frozen_string_literal: true

class Question::Narrator::Block::Reflection < Question::Narrator::Block
  def build
    block['reflections'].each_with_index do |reflection, reflection_index|
      block['reflections'][reflection_index]['audio_urls'] = prepare_urls(reflection)
    end

    block
  end

  private

  def prepare_urls(reflection)
    Question::Narrator::Block::Speech.new(self, index_processing, reflection).build['audio_urls']
  end
end
