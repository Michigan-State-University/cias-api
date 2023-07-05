# frozen_string_literal: true

class Question::HenryFordInitial < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def csv_header_names
    rename_attrs(csv_decoded_attrs).map { |attr| "henry_ford_health.#{attr}" }
  end

  def ability_to_clone?
    false
  end

  def csv_decoded_attrs
    %w[patient_id first_name last_name sex dob zip_code phone_number phone_type]
  end

  def rename_attrs(attrs)
    renamed = { 'sex' => 'gender', 'dob' => 'date_of_birth' }
    attrs.map { |attr| renamed.key?(attr) ? renamed[attr] : attr }
  end
end
