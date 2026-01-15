# frozen_string_literal: true

class V1::QuestionSerializer < V1Serializer
  attributes :type, :question_group_id, :settings, :position, :title, :subtitle, :narrator, :video_url, :formulas, :body, :original_text, :accepted_answers,
             :sms_reminders

  attribute :image_url do |object|
    polymorphic_url(object.image) if object.image.attached?
  end

  attribute :image_alt do |object|
    object.image_blob.description if object.image_blob.present?
  end

  attribute :answer_images do |object|
    object.answer_images.map do |answer_image|
      {
        url: polymorphic_url(answer_image),
        alt: answer_image.blob.description,
        answer_id: answer_image.metadata['answer_id']
      }
    end
  end

  attribute :first_question, &:first_question?

  attribute :time_ranges, if: proc { |record| record.is_a?(Question::Phone) } do |_object|
    TimeRange.order(:position).map { |time_range| { from: time_range.from, to: time_range.to, label: time_range.label } }
  end

  attribute :question_language do |object|
    object.session&.google_language&.language_code
  end

  attribute :session_multiple_fill, if: proc { |record| record.is_a?(Question::Finish) } do |object|
    object.session&.multiple_fill || false
  end
end
