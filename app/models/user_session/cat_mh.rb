# frozen_string_literal: true

class UserSession::CatMh < UserSession
  def on_answer
    update(last_answer_at: DateTime.current)
  end

  def finish(send_email: true)
    return if finished_at

    update(finished_at: DateTime.current)

    result = Api::CatMh.new.get_result(self)
    result_to_answers(result['body']) if result['status'] == 200

    GenerateUserSessionReportsJob.perform_later(id)

    V1::SmsPlans::ScheduleSmsForUserSession.call(self)
    V1::UserSessionScheduleService.new(self).schedule if send_email
    V1::ChartStatistics::CreateForUserSession.call(self)
  end

  private

  def result_to_answers(result)
    available_test_types = session.cat_mh_test_types
    result['tests'].each do |test|
      test_type = available_test_types.find_by(short_name: test['type'].downcase)
      test_type.cat_mh_test_attributes.each do |variable|
        Answer::CatMh.create!(
          user_session_id: id,
          body: {
            'data' => [
              { 'var' => "#{test_type.short_name}_#{variable.name}", 'value' => test[variable.name] }
            ]
          }
        )
      end
    end
  end
end
