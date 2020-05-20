# frozen_string_literal: true

class CreateUserLogRequests < ActiveRecord::Migration[6.0]
  def change
    create_table :user_log_requests do |t|
      t.belongs_to :user
      t.string :controller
      t.string :action
      t.jsonb :query_string
      t.jsonb :params
      t.string :user_agent
      t.inet :remote_ip

      t.timestamps
    end

    add_foreign_key :user_log_requests, :users
  end
end
