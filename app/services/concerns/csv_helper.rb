# frozen_string_literal: true

module CsvHelper
  def to_csv_timestamp(date_or_timestamp)
    date_or_timestamp.in_time_zone(ENV.fetch('CSV_TIMESTAMP_TIME_ZONE', 'UTC'))
  end

  def format_csv_timestamp(date_or_timestamp)
    to_csv_timestamp(date_or_timestamp).strftime(ENV.fetch('FILE_TIMESTAMP_NOTATION', '%m-%d-%Y_%H%M'))
  end
end
