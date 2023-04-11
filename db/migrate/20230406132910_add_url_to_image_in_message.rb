class AddUrlToImageInMessage < ActiveRecord::Migration[6.1]
  def change
    add_column(:messages, :image_url, :string)
  end
end
