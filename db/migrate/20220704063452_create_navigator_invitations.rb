class CreateNavigatorInvitations < ActiveRecord::Migration[6.1]
  def change
    create_table :navigator_invitations do |t|
      t.text :email_ciphertext
      t.string :email_bidx
      t.references :intervention, type: :uuid
      t.datetime   :accepted_at

      t.timestamps
    end

    add_index :navigator_invitations, :email_bidx
  end
end
