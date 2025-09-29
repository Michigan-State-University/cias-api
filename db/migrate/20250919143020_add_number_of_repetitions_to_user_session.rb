class AddNumberOfRepetitionsToUserSession < ActiveRecord::Migration[7.2]
  def change
    add_column :user_sessions, :number_of_repetitions, :integer, null: false, default: 0
  end
end
