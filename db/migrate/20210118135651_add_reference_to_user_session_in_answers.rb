# frozen_string_literal: true

class AddReferenceToUserSessionInAnswers < ActiveRecord::Migration[6.0]
  def up
    add_reference :answers, :user_session, foreign_key: true, type: :uuid
    remove_reference :answers, :user
  end

  def down
    remove_reference :answers, :user_session
    add_reference :answers, :user, foreign_key: true, type: :uuid
  end
end
