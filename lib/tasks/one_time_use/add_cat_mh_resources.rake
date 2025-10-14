# frozen_string_literal: true

namespace :cat_mh do
  desc 'Set up CAT-MH attachments in the database'

  def set_up_time_frames
    timeframe_details = [
      [1, 'Past hour', '1h'],
      [2, 'Past day', '1d'],
      [3, 'Past week', '1w'],
      [4, 'Past 2 weeks', '2w'],
      [5, 'Past 30 days', '30d'],
      [6, 'Past 12 months', '12m'],
      [7, 'Lifetime', 'life']
    ]
    timeframe_details.each do |(timeframe_id, description, short_name)|
      details = { timeframe_id: timeframe_id, description: description, short_name: short_name }
      AuxiliaryCatMhTimeFrame.create!(details)
    end
  end

  def set_up_languages
    languages_details = [
      [1, 'English'],
      [2, 'Spanish'],
      [3, 'Chinese - simplified'],
      [4, 'Chinese - traditional']
    ]
    languages_details.each { |(lang_id, name)| AuxiliaryCatMhLanguage.create!({ language_id: lang_id, name: name }) }
  end

  def set_up_populations
    ['General', 'Perinatal', 'Criminal justice'].each { |population| AuxiliaryCatMhPopulation.create!(name: population) }
  end

  def set_up_test_types
    languages = AuxiliaryCatMhLanguage.all
    languages_filtered = languages.limit(2)
    time_frames = AuxiliaryCatMhTimeFrame.all
    frames_filtered = time_frames.where(timeframe_id: 5..7)
    (general, perinatal, criminal_justice) = Array(AuxiliaryCatMhPopulation.all)
    test_details = [
      ['mdd', 'Major Depressive Disorder', general, languages, time_frames],
      ['dep', 'Depression', general, languages, time_frames],
      ['anx', 'Anxiety Disorder', general, languages, time_frames],
      ['m/hm', 'Mania/Hypomania', general, languages, time_frames],
      ['sud', 'Substance Use Disorder', general, languages, frames_filtered],
      ['ptsd', 'Post-Traumatic Stress Disorder', general, languages, time_frames],
      ['psy-c', 'Psychosis - Clinician', general, languages_filtered, time_frames],
      ['psy-s', 'Psychosis - Self-Report', general, languages_filtered, time_frames],
      ['a/adhd', 'Adult ADHD', general, languages_filtered, time_frames],
      ['sdoh', 'Social Determinants of Health', general, languages_filtered, time_frames],
      ['c-ssrs', 'C-SSRS Suicide Screen', general, languages, time_frames],
      ['ss', 'Suicide Scale', general, languages, time_frames],
      ['p-dep', 'Depression (Perinatal)', perinatal, languages, time_frames],
      ['p-anx', 'Anxiety Disorder (Perinatal)', perinatal, languages, time_frames],
      ['p-m/hm', 'Mania/Hypomania (Perinatal)', perinatal, languages, time_frames],
      ['cj-dep', 'Depression (Crim. Justice)', criminal_justice, languages, time_frames],
      ['cj-anx', 'Anxiety Disorder (Crim. Justice)', criminal_justice, languages, time_frames],
      ['cj-m/hm', 'Mania/Hypomania (Crim. Justice)', criminal_justice, languages, time_frames],
      ['cj-sud', 'Substance Use Disorder (CJ)', criminal_justice, languages, frames_filtered],
      ['cj-ss', 'Suicide Scale (Crim. Justice)', criminal_justice, languages, time_frames]
    ]
    test_details.each do |(short_name, name, population, langs, frames)|
      details = { short_name: short_name, name: name, cat_mh_population_id: population.id, cat_mh_languages: langs, cat_mh_time_frames: frames }
      AuxiliaryCatMhTestType.create!(details)
    end
  end

  class AuxiliaryCatMhLanguage < ActiveRecord::Base
    self.table_name = 'cat_mh_languages'
  end

  class AuxiliaryCatMhTestTypeLanguage < ActiveRecord::Base
    self.table_name = 'cat_mh_test_type_languages'

    belongs_to :cat_mh_language, class_name: 'AuxiliaryCatMhLanguage', foreign_key: :cat_mh_language_id
    belongs_to :cat_mh_test_type, class_name: 'AuxiliaryCatMhTestType', foreign_key: :cat_mh_test_type_id
  end

  class AuxiliaryCatMhTestTypeTimeFrame < ActiveRecord::Base
    self.table_name = 'cat_mh_test_type_time_frames'

    belongs_to :cat_mh_time_frame, class_name: 'AuxiliaryCatMhTimeFrame', foreign_key: :cat_mh_time_frame_id
    belongs_to :cat_mh_test_type, class_name: 'AuxiliaryCatMhTestType', foreign_key: :cat_mh_test_type_id
  end

  class AuxiliaryCatMhTestType < ActiveRecord::Base
    self.table_name = 'cat_mh_test_types'
    has_many :cat_mh_test_type_languages, dependent: :destroy, class_name: 'AuxiliaryCatMhTestTypeLanguage', foreign_key: :cat_mh_test_type_id
    has_many :cat_mh_languages, through: :cat_mh_test_type_languages, class_name: 'AuxiliaryCatMhLanguage', foreign_key: :cat_mh_test_type_id
    has_many :cat_mh_test_type_time_frames, dependent: :destroy, class_name: 'AuxiliaryCatMhTestTypeTimeFrame', foreign_key: :cat_mh_test_type_id
    has_many :cat_mh_time_frames, through: :cat_mh_test_type_time_frames, class_name: 'AuxiliaryCatMhTimeFrame', foreign_key: :cat_mh_test_type_id
  end

  class AuxiliaryCatMhPopulation < ActiveRecord::Base
    self.table_name = 'cat_mh_populations'
  end

  class AuxiliaryCatMhTimeFrame < ActiveRecord::Base
    self.table_name = 'cat_mh_time_frames'
  end


  task setup_resources: :environment do
    AuxiliaryCatMhLanguage.delete_all
    AuxiliaryCatMhTestType.delete_all
    AuxiliaryCatMhPopulation.delete_all
    AuxiliaryCatMhTimeFrame.delete_all
    set_up_time_frames
    set_up_languages
    set_up_populations
    set_up_test_types
  end
end
