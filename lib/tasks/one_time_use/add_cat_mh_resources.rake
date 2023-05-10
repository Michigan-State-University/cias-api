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
      CatMhTimeFrame.create!(details)
    end
  end

  def set_up_languages
    languages_details = [
      [1, 'English'],
      [2, 'Spanish'],
      [3, 'Chinese - simplified'],
      [4, 'Chinese - traditional']
    ]
    languages_details.each { |(lang_id, name)| CatMhLanguage.create!({ language_id: lang_id, name: name }) }
  end

  def set_up_populations
    ['General', 'Perinatal', 'Criminal justice'].each { |population| CatMhPopulation.create!(name: population) }
  end

  def set_up_test_types
    languages = CatMhLanguage.all
    languages_filtered = languages.limit(2)
    time_frames = CatMhTimeFrame.all
    frames_filtered = time_frames.where(timeframe_id: 5..7)
    (general, perinatal, criminal_justice) = Array(CatMhPopulation.all)
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
      details = { short_name: short_name, name: name, cat_mh_population: population, cat_mh_languages: langs, cat_mh_time_frames: frames }
      CatMhTestType.create!(details)
    end
  end

  task setup_resources: :environment do
    CatMhLanguage.delete_all
    CatMhTestType.delete_all
    CatMhPopulation.delete_all
    CatMhTimeFrame.delete_all
    set_up_time_frames
    set_up_languages
    set_up_populations
    set_up_test_types
  end
end
