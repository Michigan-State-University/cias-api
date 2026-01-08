# frozen_string_literal: true

class V1::Question::AnswerImage::Update
  include V1::Question::AnswerImage::AnswerImageHelper

  def initialize(question, answer_id, image_alt)
    @question = question
    @answer_id = answer_id
    @image_alt = image_alt
  end

  def self.call(question, answer_id, image_alt)
    new(question, answer_id, image_alt).call
  end

  def call
    raise ArgumentError, 'Wrong answer_id' if answer_index.blank?

    attachment = find_answer_image
    raise ActiveRecord::RecordNotFound if attachment.blank?

    attachment.blob.update!(description: image_alt)
    question
  end

  private

  attr_accessor :question
  attr_reader :answer_id, :image_alt
end
