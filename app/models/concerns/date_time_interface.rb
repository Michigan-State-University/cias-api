# frozen_string_literal: true

module DateTimeInterface
  def time_diff(start_time, end_time)
    seconds_diff = end_time - start_time
    duration = ActiveSupport::Duration.build(seconds_diff.abs)
    parts = duration.parts
    total_hours = (parts[:hours] || 0) + ((parts[:days] || 0) * 24)
    format('%<hours>02d:%<minutes>02d:%<seconds>02d',
           hours: total_hours,
           minutes: parts[:minutes] || 0,
           seconds: parts[:seconds] || 0)
  end
end
