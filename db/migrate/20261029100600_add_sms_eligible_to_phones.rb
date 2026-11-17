# frozen_string_literal: true

class AddSmsEligibleToPhones < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :phones, :sms_eligible, :boolean, null: false, default: false unless column_exists?(:phones, :sms_eligible)

    Phone.reset_column_information
    without_versioning do
      Phone.find_each do |phone|
        phone.save
      rescue StandardError
        next
      end
    end
  end

  def down
    remove_column :phones, :sms_eligible
  end

  private

  def without_versioning
    PaperTrail.request(enabled: false) do
      Phone.without_auditing { yield }
    end
  end
end
