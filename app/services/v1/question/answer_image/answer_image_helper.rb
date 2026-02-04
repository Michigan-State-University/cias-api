# frozen_string_literal: true

module V1::Question::AnswerImage::AnswerImageHelper
  protected

  def find_answer_image
    question.answer_images.joins(:blob)
             .find_by("(active_storage_blobs.metadata::jsonb)->>'answer_id' = ?", answer_id)
  end

  def answer_index
    @answer_index ||= question.body&.dig('data')&.find_index { |answer| answer['id'].eql?(answer_id) }
  end
end
