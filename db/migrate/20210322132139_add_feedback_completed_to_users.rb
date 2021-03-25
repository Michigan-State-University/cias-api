# frozen_string_literal: true

class AddFeedbackCompletedToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :feedback_completed, :boolean, default: false, null: false
  end
end
