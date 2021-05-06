# frozen_string_literal: true

class RemoveUnencryptedSensitiveData < ActiveRecord::Migration[6.0]
  def change
    reversible do |dir|
      change_table :users do |t|
        dir.up do
          t.remove :first_name
          t.remove :last_name
          t.remove :email
          t.remove :uid
        end

        dir.down do
          t.remove :first_name
          t.remove :last_name
          t.remove :email
          t.remove :uid
        end
      end
    end

    remove_column :phones, :number, :string
    remove_column :messages, :phone, :string
    remove_column :invitations, :email, :string
  end
end
