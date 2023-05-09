# frozen_string_literal: true

namespace :one_time_use do
  desc 'Add basic time range'
  task seeds_time_ranges: :environment do
    p 'Adding time range to SMSes'

    range_details = [
      {from: 7, to: 9, position: 10, label: :early_morning},
      {from: 9, to: 12, position: 20, label: :mid_morning},
      {from: 12, to: 17, position: 30, label: :afternoon, default: true },
      {from: 17, to: 20, position: 40, label: :early_evening},
      {from: 20, to: 22, position: 50, label: :night },
    ]

    range_details.each do |range|
      TimeRange.create(range)
    end
  end
end
