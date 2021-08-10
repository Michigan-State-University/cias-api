# frozen_string_literal: true

class Question::Narrator::Block::Reflection < Question::Narrator::Block
  def build
    block['reflections'].each_with_index do |reflection, reflection_index|
      block['reflections'][reflection_index]['audio_urls'] =
        Speech.new(self, index_processing, reflection).build['audio_urls']
    end

    block
  end

  def swap_name(block, mp3url, name_text)
    block['reflections'].each do |reflection|
      next reflection unless reflection['text'].include?(':name:.')

      swap_name_into_block(reflection, mp3url, name_text)
    end
    block
  end
end
