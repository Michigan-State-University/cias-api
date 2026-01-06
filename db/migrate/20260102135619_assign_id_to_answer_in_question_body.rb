class AssignIdToAnswerInQuestionBody < ActiveRecord::Migration[7.2]
  def up
    p '-- add new properties to body in single, multiple and third party question -> answer id'
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
      WHERE type IN ('Question::ThirdParty', 'Question::Single', 'Question::Multiple')
    SQL
    ActiveRecord::Base.connection.exec_query(query)

    p '-- add new properties to body in grid question -> answer id'
    grid_query = <<~SQL.squish
      UPDATE questions
      SET body = jsonb_set(
        body,
        '{data}',
        (
          SELECT jsonb_agg(
            jsonb_set(
              jsonb_set(
                element,
                '{id}',
                to_jsonb(uuid_generate_v4()),
                true
              ),
              '{payload}',
              jsonb_set(
                jsonb_set(
                  element->'payload',
                  '{rows}',
                  (
                    SELECT jsonb_agg(
                      jsonb_set(row_el, '{id}', to_jsonb(uuid_generate_v4()), true)
                    )
                    FROM jsonb_array_elements(element->'payload'->'rows') AS row_el
                  ),
                  true
                ),
                '{columns}',
                (
                  SELECT jsonb_agg(
                    jsonb_set(col_el, '{id}', to_jsonb(uuid_generate_v4()), true)
                  )
                  FROM jsonb_array_elements(element->'payload'->'columns') AS col_el
                ),
                true
              ),
              true
            )
          )
          FROM jsonb_array_elements(body->'data') AS element
        )
      )
      WHERE type IN ('Question::Grid');
    SQL
    ActiveRecord::Base.connection.exec_query(grid_query)
  end

  def down
    raise(ActiveRecord::IrreversibleMigration)
  end
end
