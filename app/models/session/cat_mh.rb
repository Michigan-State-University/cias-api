# frozen_string_literal: true

class Session::CatMh < Session
  belongs_to :cat_mh_language, optional: true
  belongs_to :cat_mh_time_frame, optional: true
  belongs_to :cat_mh_population, optional: true

  def translate_questions(_translator, _source_language_name_short, _destination_language_name_short); end

  def user_session_type
    UserSession::CatMh.name
  end
end
