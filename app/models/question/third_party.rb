# frozen_string_literal: true

class Question::ThirdParty < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def self.assign_default_values(attr)
    super(attr).merge(
      { 'required' => false }
    )
  end

  def csv_header_names
    []
  end

  def translate_body(translator, source_language_name_short, destination_language_name_short)
    body['data'].each do |row|
      row['original_text'] = row['payload']

      row['payload']= translator.translate(row['payload'], source_language_name_short, destination_language_name_short)
    end
  end
end
