# frozen_string_literal: true

class CreateTeams < ActiveRecord::Migration[6.0]
  def change
    create_table :teams, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.string :name, null: false

      t.timestamps
    end
  end
end
