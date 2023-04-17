# frozen_string_literal: true

namespace :one_time_use do
  desc 'Update narrator settings - add a new filed to all exising question (skip TLFB questions)'
  task update_narrator_settings: :environment do
    p 'UPDATING...'
    time = Benchmark.realtime {
      query = <<~SQL.squish
      UPDATE questions
      SET narrator = jsonb_set(narrator, '{settings, extra_space_for_narrator}', 'false', true)
      WHERE type NOT IN ('Question::TlfbConfig', 'Question::TlfbEvents', 'Question::TlfbQuestion')
      SQL
      ActiveRecord::Base.connection.exec_query(query)
    }
    p "all done in #{time} seconds"
    p 'DONE!'
  end
end
