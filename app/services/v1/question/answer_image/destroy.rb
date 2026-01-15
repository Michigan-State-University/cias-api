# frozen_string_literal: true

class V1::Question::AnswerImage::Destroy
  include V1::Question::AnswerImage::AnswerImageHelper

  def initialize(question, answer_id)
    @question = question
    @answer_id = answer_id
  end

  def self.call(question, answer_id)
    new(question, answer_id).call
  end

  def call
    raise ArgumentError, 'Wrong answer_id' if answer_index.blank?

    attachment = find_answer_image
    raise ActiveRecord::RecordNotFound if attachment.blank?

    update_body!
    attachment.purge

    question
  end

  private

  attr_accessor :question
  attr_reader :answer_id

  def update_body!
    question.body['data'][answer_index].delete('image_id')
    question.save!
  end
end
