class RunRakeTaskToFixCharacterAndSliderQuestions < ActiveRecord::Migration[6.1]
  def change
    Rake::Task['one_time_use:assign_missing_character_and_fix_slider_questions'].invoke
  end
end
