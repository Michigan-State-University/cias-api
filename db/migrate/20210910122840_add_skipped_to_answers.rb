class AddSkippedToAnswers < ActiveRecord::Migration[6.0]
  def change
    add_column :answers, :skipped, :boolean, default: false
  end
end
