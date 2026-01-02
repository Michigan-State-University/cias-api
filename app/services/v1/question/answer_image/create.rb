# frozen_string_literal: true

class V1::Question::AnswerImage::Create
  include V1::Question::AnswerImage::AnswerImageHelper

  def initialize(question, answer_id, file)
    @question = question
    @answer_id = answer_id
    @file = file
  end

  def self.call(question, answer_id, file)
    new(question, answer_id, file).call
  end

  def call
    raise ArgumentError, 'Wrong answer_id' if answer_index.blank?
    raise ActiveRecord::RecordNotSaved if answer_has_attached_image?

    @blob = ActiveStorage::Blob.create_and_upload!(
      io: file,
      filename: file.original_filename,
      content_type: file.content_type,
      metadata: { answer_id: answer_id }
    )

    question.answer_images.attach(blob)
    assign_image_to_answer!
    question
  end

  private

  attr_accessor :question, :blob
  attr_reader :file, :answer_id

  def assign_image_to_answer!
    question.body['data'][answer_index]['image_id'] = blob.attachment_ids.first
    question.save!
  end

  def answer_has_attached_image?
    find_answer_image.present?
  end
end
