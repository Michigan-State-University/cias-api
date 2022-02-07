# frozen_string_literal: true

class ChangeTlfbSubstanceAssociation < ActiveRecord::Migration[6.1]
  def change
    remove_reference :substances, :user_session, foreign_key: true

    add_reference :substances, :day, foreign_key: true, index: true, null: false
  end
end
