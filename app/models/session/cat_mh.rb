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

  def contains_necessary_resources?
    cat_mh_language_id.present? && cat_mh_population_id.present? && cat_mh_time_frame_id.present? && cat_mh_test_types.size.positive?
  end

  def fetch_variables(filter_options = {})
    cat_mh_test_types.map do |type|
      target_attrs = filter_options[:only_digit_variables] ? type.cat_mh_test_attributes.where(variable_type: 'number') : type.cat_mh_test_attributes
      variable_names = target_attrs.map { |var| "#{type.short_name}_#{var.name}" }
      {
        subtitle: type.name,
        variables: variable_names
      }
    end
  end

  def assign_google_tts_voice(first_session)
    session_voice = first_session&.google_tts_voice

    if first_session.blank?
      self.cat_mh_language = CatMhLanguage.find_by(name: intervention.google_language.language_name)
      self.google_tts_voice = cat_mh_language&.google_tts_voices&.first
    else
      self.cat_mh_language = CatMhLanguage.find_by(name: first_session.google_tts_voice&.google_tts_language&.language_name&.split&.first)
      self.google_tts_voice = cat_mh_language&.google_tts_voices&.find_by(id: session_voice.id)
    end
  end
end
