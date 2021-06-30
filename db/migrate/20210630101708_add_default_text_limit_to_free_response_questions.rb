class AddDefaultTextLimitToFreeResponseQuestions < ActiveRecord::Migration[6.0]
  def self.up
    Question::FreeResponse.update_all("settings = jsonb_set(settings, '{text_limit}', to_json(250)::jsonb)")
  end

  def self.down; end
end
