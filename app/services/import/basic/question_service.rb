# frozen_string_literal: true

class Import::Basic::QuestionService
  include ImportOperations
  def self.call(question_group_id, question_hash)
    new(
      question_group_id,
      question_hash.except(:version)
    ).call
  end

  def initialize(question_group_id, question_hash)
    @question_group_id = question_group_id
    @question_hash = question_hash
    @image = question_hash.delete(:image)
  end

  attr_reader :question_hash, :question_group_id, :image

  def call
    question_hash.delete(:relations_data)
    question = Question.create!(question_hash.merge({ question_group_id: question_group_id, image: import_file(image) }))
    add_description!(question) unless image.nil?
    question
  end

  private

  def add_description!(question)
    question.image_blob&.update(description: image[:description])
  end
end
