
namespace :one_time_use do
  desc 'Removes all question groups with no questions'
  task delete_empty_question_groups: :environment do
    QuestionGroup.where.missing(:questions).delete_all
  end
end
