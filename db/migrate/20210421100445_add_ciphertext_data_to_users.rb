# frozen_string_literal: true

class AddCiphertextDataToUsers < ActiveRecord::Migration[6.0]
  def change
    # encrypted data
    add_column :users, :email_ciphertext, :text
    add_column :users, :first_name_ciphertext, :text
    add_column :users, :last_name_ciphertext, :text
    add_column :users, :uid_ciphertext, :text

    # blind index
    add_column :users, :email_bidx, :string
    add_index :users, :email_bidx, unique: true
    add_column :users, :uid_bidx, :string
    add_index :users, :uid_bidx, unique: true
  end
end
