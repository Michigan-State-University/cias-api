# frozen_string_literal: true

class Session::CatMh < Session
  belongs_to :cat_mh_language
  belongs_to :cat_mh_time_frame
  belongs_to :cat_mh_population

  def translate_questions(_translator, _source_language_name_short, _destination_language_name_short); end
end
