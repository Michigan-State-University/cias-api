class AddDraftToAnswers < ActiveRecord::Migration[6.1]
  def change
    add_column :answers, :draft, :boolean, default: false
  end
end
