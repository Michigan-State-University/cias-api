# frozen_string_literal: true

class SplitRolesExistingUsers < ActiveRecord::Migration[6.1]
  def change
    Rake::Task['users:add_additional_roles_to_existed_users'].invoke
  end
end
