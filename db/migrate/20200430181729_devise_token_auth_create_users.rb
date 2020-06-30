# frozen_string_literal: true

class DeviseTokenAuthCreateUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :users, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      ## Required
      t.string :provider, null: false, default: 'email'
      t.string :uid, null: false, default: ''

      ## User Info
      t.string :first_name, null: false, default: ''
      t.string :middle_name
      t.string :last_name, null: false, default: ''
      t.string :username
      t.string :email

      ## Authorization
      t.text :roles, default: [], array: true

      ## Tokens
      t.jsonb :tokens

      ## Deactivate user instead of destroy
      t.boolean :deactivated, null: false, default: false

      ## Confirmable
      t.string   :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string   :unconfirmed_email # Only if using reconfirmable

      ## Database authenticatable
      t.string :encrypted_password, null: false, default: ''

      ## Lockable
      # t.integer  :failed_attempts, :default => 0, :null => false # Only if lock strategy is :failed_attempts
      # t.string   :unlock_token # Only if unlock strategy is :email or :both
      # t.datetime :locked_at

      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at
      t.boolean  :allow_password_change, null: false, default: false

      ## Rememberable
      t.datetime :remember_created_at

      ## Trackable
      t.integer  :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.inet     :current_sign_in_ip
      t.inet     :last_sign_in_ip

      t.timestamps
    end

    add_index :users, :uid, unique: true
    add_index :users, :email, unique: true
    add_index :users, :username, unique: true
    add_index :users, :roles, using: :gin
    add_index :users, %i[uid provider], unique: true
    add_index :users, %i[uid roles], using: :gin
    add_index :users, :reset_password_token, unique: true
    add_index :users, :confirmation_token, unique: true
    # add_index :users, :unlock_token, unique: true
  end
end
