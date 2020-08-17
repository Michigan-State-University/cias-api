# frozen_string_literal: true

class Question::Narrator::Block::ReadQuestion < Question::Narrator::Block
  def build
    Question::Narrator::Block::Speech.new(self, index_processing, block).build
  end
end
