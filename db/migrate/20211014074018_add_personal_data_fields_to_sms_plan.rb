class AddPersonalDataFieldsToSmsPlan < ActiveRecord::Migration[6.0]
  def change
    column_names = %w[first_name last_name phone_number email]
    column_names.each { |column| add_column(:sms_plans, "include_#{column}", :boolean) }
  end
end
