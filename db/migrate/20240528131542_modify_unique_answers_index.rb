class ModifyUniqueAnswersIndex < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
          DROP INDEX IF EXISTS index_answers_on_user_session_id_and_question_id;
    SQL

    # add_index :answers, %i[user_session_id question_id type], where: "(created_at > '2023-10-25 05:30:04'::timestamp AND NOT (type = ANY (ARRAY['Answer::Sms', 'Answer::SmsInformation'])))", unique: true
  end

  def down
    execute <<-SQL.squish
          DROP INDEX IF EXISTS index_answers_on_user_session_id_and_question_id_and_type;
    SQL

    add_index :answers, %i[user_session_id question_id], where: "(created_at > '2023-10-25 05:30:04'::timestamp)", unique: true
  end
end
