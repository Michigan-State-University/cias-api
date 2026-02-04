# frozen_string_literal: true

class Import::V3::QuestionService < Import::Basic::QuestionService
  def initialize(question_group_id, question_hash)
    super
    @answer_images = question_hash.delete(:answer_images)
  end

  attr_reader :answer_images

  def call
    question_hash.delete(:relations_data)
    question = Question.create!(question_hash.merge({ question_group_id: question_group_id }))
    attach_image_directly(question) if image.present?
    attach_answer_images(question) if answer_images.present?

    question
  end

  private

  def attach_answer_images(question)
    added_images = answer_images&.map do |answer_image|
      blob = import_file_directly(question, :answer_images, answer_image)
      answer_id = answer_image[:metadata][:answer_id]
      blob.metadata['answer_id'] = answer_id
      blob.description = answer_image[:description]
      blob.save

      answer_index = question.body&.dig('data')&.find_index { |answer| answer['id'].eql?(answer_id) }
      next if answer_index.blank?

      { answer_index: answer_index, attachment_id: blob.attachment_ids.first }
    end

    added_images.compact.each do |img|
      question.body['data'][img[:answer_index]]['image_id'] = img[:attachment_id]
    end
    question.save!
  end
end
