# frozen_string_literal: true

namespace :one_time_use do
  task assign_id_to_questions_answers: :environment do
    Question.where(type: %w[Question::Single Question::Multiple Question::ThirdParty]).find_each do |question|
      question.body['data'].each_with_index do |answer, index|
        question.body['data'][index]['id'] ||= SecureRandom.uuid
      end
      question.save!
    end
  end
end
