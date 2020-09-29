# frozen_string_literal: true

class V1::Questions::Show < BaseSerializer
  def cache_key
    "question/#{question.id}-#{question.updated_at&.to_s(:number)}"
  end

  def to_json
    {
      id: question.id,
      question_group_id: question.question_group_id,
      type: question.type,
      settings: question.settings,
      position: question.position,
      title: question.title,
      subtitle: question.subtitle,
      narrator: question.narrator,
      image_url: url_for_image(question),
      video_url: question.video_url,
      formula: question.formula,
      body: question.body
    }
  end

  private

  attr_reader :question
end
