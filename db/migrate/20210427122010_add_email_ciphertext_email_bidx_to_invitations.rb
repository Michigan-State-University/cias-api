class AddEmailCiphertextEmailBidxToInvitations < ActiveRecord::Migration[6.0]
  def change
    # encrypted data
    add_column :invitations, :email_ciphertext, :text

    # blind index
    add_column :invitations, :email_bidx, :string
    add_index :invitations, :email_bidx
  end
end
