class AddVideoStatsToAnswers < ActiveRecord::Migration[6.1]
  def change
    add_column :answers, :video_stats, :jsonb, default: {}
  end
end
