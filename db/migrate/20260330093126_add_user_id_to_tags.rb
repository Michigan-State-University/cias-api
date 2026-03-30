# frozen_string_literal: true

class AddUserIdToTags < ActiveRecord::Migration[7.2]
  def up
    add_reference :tags, :user, type: :uuid, foreign_key: true, null: true, index: true

    # Backfill: assign each tag to the owner of the first intervention it was used on
    execute <<-SQL.squish
      UPDATE tags
      SET user_id = (
        SELECT interventions.user_id
        FROM tag_interventions
        JOIN interventions ON interventions.id = tag_interventions.intervention_id
        WHERE tag_interventions.tag_id = tags.id
        ORDER BY tag_interventions.created_at ASC
        LIMIT 1
      )
      WHERE user_id IS NULL
    SQL

    # Delete orphaned tags (not assigned to any intervention, no owner)
    execute 'DELETE FROM tags WHERE user_id IS NULL'

    change_column_null :tags, :user_id, false

    # Replace global name uniqueness with per-user uniqueness
    remove_index :tags, :name
    add_index :tags, %i[name user_id], unique: true
  end

  def down
    # Deduplicate tags by name before restoring global uniqueness —
    # multiple users may now have tags with the same name
    execute <<-SQL.squish
      DELETE FROM tag_interventions
      WHERE tag_id IN (
        SELECT id FROM tags
        WHERE id NOT IN (
          SELECT MIN(id) FROM tags GROUP BY name
        )
      )
    SQL

    execute <<-SQL.squish
      DELETE FROM tags
      WHERE id NOT IN (
        SELECT MIN(id) FROM tags GROUP BY name
      )
    SQL

    remove_index :tags, %i[name user_id]
    remove_reference :tags, :user
    add_index :tags, :name, unique: true
  end
end
