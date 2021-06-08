# frozen_string_literal: true

class AddPhoneCiphertextToMessages < ActiveRecord::Migration[6.0]
  def change
    add_column :messages, :phone_ciphertext, :text
  end
end
