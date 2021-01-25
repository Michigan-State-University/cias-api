# frozen_string_literal: true

class AddDefaultAfterFillScheduleOption < ActiveRecord::Migration[6.0]
  def up
    change_column_default :sessions, :schedule, 'after_fill'
  end

  def down
    change_column_default :sessions, :schedule, nil
  end
end
