# frozen_string_literal: true

class Question::Narrator::Block::ReflectionFormula < Question::Narrator::Block
  def build
    block['reflections'].each_with_index do |reflection, reflection_index|
      block['reflections'][reflection_index]['audio_urls'] = Speech.new(self, index_processing, reflection).build['audio_urls']
    end
    block
  end
end
