# frozen_string_literal: true

class Session::CatMh < Session
  belongs_to :cat_mh_language, optional: true
  belongs_to :cat_mh_time_frame, optional: true
  belongs_to :cat_mh_population, optional: true
  has_many :tests, dependent: :destroy, foreign_key: :session_id, inverse_of: :session
  has_many :cat_mh_test_types, through: :tests

  def translate_questions(_translator, _source_language_name_short, _destination_language_name_short); end

  def user_session_type
    UserSession::CatMh.name
  end

  def fetch_variables(filter_options = {})
    cat_mh_test_types.flat_map do |type|
      target_attrs = filter_options[:only_digit_variables] ? type.cat_mh_test_attributes.where(variable_type: 'number') : type.cat_mh_test_attributes
      target_attrs.map { |var| "#{type.short_name}_#{var.name}" }
    end
  end
end
