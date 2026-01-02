class AssignIdToAnswerInQuestionBody < ActiveRecord::Migration[7.2]
  def up
    p '-- add new properties to body in single, multiple and third party question -> answer id'
    # q = Question.where(type: ['Question::ThirdParty', 'Question::Single', 'Question::Multiple']).order(:created_at)[5]
    query = <<~SQL.squish
      UPDATE questions
      SET
        body = jsonb_set (
          body,
          '{data}',
          (
            SELECT
              jsonb_agg(jsonb_set (element, '{id}', to_jsonb(uuid_generate_v4()), true))
            FROM
              jsonb_array_elements(body -> 'data') AS element
          )
        )
      WHERE id IN ('4bb166ef-e27f-43f5-add3-c25f62edbd67')
--       WHERE type IN ('Question::ThirdParty', 'Question::Single', 'Question::Multiple')
    SQL
    ActiveRecord::Base.connection.exec_query(query)
  end

  def down
    raise(ActiveRecord::IrreversibleMigration)
  end
end
