class AddNumberCiphertextToPhones < ActiveRecord::Migration[6.0]
  def change
    add_column :phones, :number_ciphertext, :text
  end
end
