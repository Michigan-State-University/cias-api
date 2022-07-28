namespace :one_time_use do
  desc "Fix invalid questions counter for all question groups"
  task fix_questions_counter: :environment do
    ActiveRecord::Base.connection.execute("UPDATE question_groups
       SET questions_count = (SELECT count(1)
       FROM questions
       WHERE questions.question_group_id = question_groups.id);")
  end

end
