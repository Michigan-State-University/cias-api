class SetUpCatMhAndGoogleTtsRelationships < ActiveRecord::Migration[6.0]
  def change
    Rake::Task['cat_mh:setup_language_voice_relationships'].invoke
  end
end
