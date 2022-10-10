# frozen_string_literal: true

class Question::HenryFordInitial < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def self.csv_decoded_attrs
    %w[patient_id first_name last_name sex dob zip_code]
  end

  def self.rename_attrs!(attrs)
    renamed = { 'sex' => 'gender', 'dob' => 'date_of_birth' }
    attrs.map { |attr| renamed.key?(attr) ? renamed[attr] : attr }
  end

  def csv_header_names
    []
  end

  def question_variables
    attrs = HenryFordInitial.csv_decoded_attrs
    HenryFordInitial.rename_attrs!(attrs).map { |attr| "hfs.#{attr}" }
  end

  def ability_to_clone?
    false
  end
end
