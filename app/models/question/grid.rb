# frozen_string_literal: true

class Question::Grid < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def self.assign_default_values(attr)
    super(attr).merge(
      { 'proceed_button' => true, 'required' => true }
    )
  end

  def csv_header_names
    body_data.first['payload']['rows'].map { |row| row['variable']['name'] }
  end

  def variable_clone_prefix
    body_data[0]['payload']['rows']&.each do |row|
      row['variable']['name'] = "clone_#{row['variable']['name']}" if row['variable']['name'].presence
    end
  end
end
