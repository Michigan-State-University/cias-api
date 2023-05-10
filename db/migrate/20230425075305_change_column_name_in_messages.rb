class ChangeColumnNameInMessages < ActiveRecord::Migration[6.1]
  def change
    rename_column :messages, :image_url, :attachment_url
  end
end
