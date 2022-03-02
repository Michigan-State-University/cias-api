class MakeTlfbQuestionsRequired < ActiveRecord::Migration[6.1]
  def change
    Rake::Task['tlfb:set_required'].invoke
  end
end
