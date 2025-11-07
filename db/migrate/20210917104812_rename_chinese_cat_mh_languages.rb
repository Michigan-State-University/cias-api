class RenameChineseCatMhLanguages < ActiveRecord::Migration[6.0]
  def change
    simplified = AuxiliaryCatMhLanguage.find_by(name: 'Chinese - simplified')
    traditional = AuxiliaryCatMhLanguage.find_by(name: 'Chinese - traditional')
    simplified&.update!(name: 'Chinese (Simplified)')
    traditional&.update!(name: 'Chinese (Traditional)')
  end

  class AuxiliaryCatMhLanguage < ActiveRecord::Base
    self.table_name = 'cat_mh_languages'
  end
end
