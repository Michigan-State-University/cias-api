# frozen_string_literal: true

namespace :one_time_use do
  desc 'Add basic time range'
  task seeds_time_range: :environment do
    p 'Adding time range to SMSes'

    range_details = [
      {from: 0, to: 6, position: 10 },
      {from: 6, to: 9, position: 20},
      {from: 9, to: 12, position: 30 },
      {from: 12, to: 16, position: 40 },
      {from: 16, to: 19, position: 50 },
      {from: 19, to: 24, position: 60 },
    ]

    range_details.each do |range|
      TimeRange.create(range)
    end
  end
end
