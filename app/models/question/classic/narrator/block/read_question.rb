# frozen_string_literal: true

class Question::Classic::Narrator::Block::ReadQuestion < Question::Classic::Narrator::Block
  def build
    Question::Classic::Narrator::Block::Speech.new(self, index_processing, block).build
  end
end
