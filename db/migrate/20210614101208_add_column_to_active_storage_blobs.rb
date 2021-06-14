# frozen_string_literal: true

class AddColumnToActiveStorageBlobs < ActiveRecord::Migration[6.0]
  def change
    add_column :active_storage_blobs, :description, :string
  end
end
