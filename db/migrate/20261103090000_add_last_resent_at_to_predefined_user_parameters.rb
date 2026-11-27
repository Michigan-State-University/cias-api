# frozen_string_literal: true

class AddLastResentAtToPredefinedUserParameters < ActiveRecord::Migration[8.1]
  def change
    add_column :predefined_user_parameters, :last_resent_at, :datetime
  end
end
