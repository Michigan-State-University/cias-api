class AddNewParametersToExistingThirdPartyQuestions < ActiveRecord::Migration[6.1]
  def up
    p '-- add new properties to body in third party question'
    query = <<~SQL.squish
      UPDATE questions
      SET
        body = jsonb_set (
          jsonb_set(body, '{variable}', '{"name": ""}', true ),
          '{data}',
          (
            SELECT
              jsonb_agg(jsonb_set (element, '{numeric_value}', '""', true))
            FROM
              jsonb_array_elements(body -> 'data') AS element
          )
        )
      WHERE type IN ('Question::ThirdParty')
    SQL
    ActiveRecord::Base.connection.exec_query(query)
  end

  def down
    # raise(ActiveRecord::IrreversibleMigration)
  end
end
