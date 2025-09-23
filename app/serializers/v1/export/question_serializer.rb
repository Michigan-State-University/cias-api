# frozen_string_literal: true

class V1::Export::QuestionSerializer < ActiveModel::Serializer
  include FileHelper
  include ExportHelper

  attributes :type, :settings, :position, :title, :subtitle, :narrator, :video_url, :formulas, :body, :original_text

  attribute :duplicated do
    true
  end

  attribute :relations_data do
    branching_data(object) + reflection_data(object)
  end

  attribute :image do
    export_file(object.image)
  end

  attribute :version do
    Question::CURRENT_VERSION
  end

  private

  def branching_data(question)
    branch_target_locations = []
    targets = question.formulas.flat_map { |formula| formula['patterns'].flat_map { |pattern| pattern['target'] } }
    targets.each do |target|
      next if target['id'].blank?

      if target['type'].include?('Question')
        target_question = Question.find_by(id: target['id'])
        next if target_question.nil?

        target_question_group_position = target_question.question_group.position
        location = object_location(target_question, :question_group_position, target_question_group_position)
      elsif target['type'].include?('Session')
        target_session = Session.find(target['id'])
        location = object_location(target_session)
      end
      branch_target_locations << location unless branch_target_locations.include?(location)
    end
    branch_target_locations
  end

  def reflection_data(question)
    reflection_target_locations = []
    reflections = question.narrator['blocks'].filter { |block| block['type'] == 'Reflection' }
    reflections.each do |reflection|
      target_question = Question.find_by(id: reflection['question_id'])
      next if target_question.nil?

      target_question_group_position = target_question.question_group.position
      reflection_target_locations << object_location(target_question, :question_group_position, target_question_group_position)
    end
    reflection_target_locations
  end
end
