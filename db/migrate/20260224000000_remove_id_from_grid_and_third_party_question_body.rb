# frozen_string_literal: true

class RemoveIdFromGridAndThirdPartyQuestionBody < ActiveRecord::Migration[7.2]
  def up
    say '-- remove id from body->data[] for Question::ThirdParty'
    third_party_query = <<~SQL.squish
      UPDATE questions
      SET body = jsonb_set(
        body,
        '{data}',
        (
          SELECT jsonb_agg(element - 'id')
          FROM jsonb_array_elements(body -> 'data') AS element
        )
      )
      WHERE type = 'Question::ThirdParty'
    SQL
    ActiveRecord::Base.connection.exec_query(third_party_query)

    say '-- remove id from body->data[0] and from rows/columns for Question::Grid'
    grid_query = <<~SQL.squish
      UPDATE questions
      SET body = jsonb_set(
        body,
        '{data}',
        (
          SELECT jsonb_agg(
            jsonb_set(
              (element - 'id'),
              '{payload}',
              jsonb_set(
                jsonb_set(
                  element -> 'payload',
                  '{rows}',
                  (
                    SELECT jsonb_agg(row_el - 'id')
                    FROM jsonb_array_elements(element -> 'payload' -> 'rows') AS row_el
                  ),
                  true
                ),
                '{columns}',
                (
                  SELECT jsonb_agg(col_el - 'id')
                  FROM jsonb_array_elements(element -> 'payload' -> 'columns') AS col_el
                ),
                true
              ),
              true
            )
          )
          FROM jsonb_array_elements(body -> 'data') AS element
        )
      )
      WHERE type = 'Question::Grid'
    SQL
    ActiveRecord::Base.connection.exec_query(grid_query)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
