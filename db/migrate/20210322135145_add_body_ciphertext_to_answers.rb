# frozen_string_literal: true

class AddBodyCiphertextToAnswers < ActiveRecord::Migration[6.0]
  def change
    add_column :answers, :body_ciphertext, :text
  end
end
