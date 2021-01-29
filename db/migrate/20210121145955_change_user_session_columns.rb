# frozen_string_literal: true

class ChangeUserSessionColumns < ActiveRecord::Migration[6.0]
  def up
    change_table :user_sessions, bulk: true do |t|
      t.rename :submitted_at, :finished_at
      t.remove :schedule_at
      t.datetime :last_answer_at
      t.string :timeout_job_id
    end
  end

  def down
    change_table :user_sessions, bulk: true do |t|
      t.rename :finished_at, :submitted_at
      t.remove :last_answer_at
      t.remove :timeout_job_id
      t.datetime schedule_at
    end
  end
end
