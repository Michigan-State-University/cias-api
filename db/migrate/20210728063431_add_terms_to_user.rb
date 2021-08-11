# frozen_string_literal: true

class AddTermsToUser < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :terms, :boolean, default: false, null: false
    add_column :users, :terms_confirmed_at, :datetime
  end
end
