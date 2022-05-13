class RenameChineseCatMhLanguages < ActiveRecord::Migration[6.0]
  def change
    simplified = CatMhLanguage.find_by(name: 'Chinese - simplified')
    traditional = CatMhLanguage.find_by(name: 'Chinese - traditional')
    simplified&.update!(name: 'Chinese (Simplified)')
    traditional&.update!(name: 'Chinese (Traditional)')
  end
end
