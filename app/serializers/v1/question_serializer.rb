# frozen_string_literal: true

class V1::QuestionSerializer < V1Serializer
  attributes :type, :question_group_id, :settings, :position, :title, :subtitle, :narrator, :video_url, :formulas, :body, :original_text, :accepted_answers

  attribute :image_url do |object|
    polymorphic_url(object.image) if object.image.attached?
  end

  attribute :image_alt do |object|
    object.image_blob.description if object.image_blob.present?
  end

  attribute :first_question, &:first_question?

  attribute :time_ranges, if: proc { |record| record.is_a?(Question::Phone) } do |_object|
    TimeRange.all.order(:position).map { |time_range| { from: time_range.from, to: time_range.to, label: time_range.label } }
  end
end
