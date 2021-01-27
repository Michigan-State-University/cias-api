# frozen_string_literal: true

class V1::UserSessionScheduleService
  def initialize(user_session)
    @user_session = user_session
  end

  attr_reader :user_session

  def schedule
    next_session = user_session.session.next_session
    return if next_session.nil?

    send("#{next_session.schedule}_schedule", next_session)
  end

  def after_fill_schedule(next_session)
    next_session.send_link_to_session(user_session.user)
  end

  def days_after_schedule(_next_session)
    nil
  end

  def days_after_fill_schedule(_next_session)
    nil
  end

  def exact_date_schedule(_next_session)
    nil
  end
end
