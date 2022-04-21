class AddRedirectedSessionIdToAnswers < ActiveRecord::Migration[6.0]
  def change
    add_column :answers, :next_session_id, :uuid
  end
end
