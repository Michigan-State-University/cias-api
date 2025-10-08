class AddCompletionMessage < ActiveRecord::Migration[7.2]
  def change
    add_column(:sessions, :completion_message, :text)
  end
end
