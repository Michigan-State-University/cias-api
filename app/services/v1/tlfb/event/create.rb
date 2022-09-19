# frozen_string_literal: true

class V1::Tlfb::Event::Create
  def self.call(exact_date, user_session_id, question_group_id)
    new(exact_date, user_session_id, question_group_id).call
  end

  def initialize(exact_date, user_session_id, question_group_id)
    @exact_date = exact_date
    @user_session_id = user_session_id
    @question_group_id = question_group_id
  end

  def call
    day = Tlfb::Day.find_or_create_by(
      exact_date: exact_date,
      user_session_id: user_session_id,
      question_group_id: question_group_id
    )

    Tlfb::Event.create!(day: day)
  end

  private

  attr_reader :exact_date, :user_session_id, :question_group_id
end
