# frozen_string_literal: true

class UserSession::CatMh < UserSession
  after_create_commit :initialize_user_session

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

  def initialize_user_session
    cat_mp_service = Api::CatMh.new
    result = cat_mp_service.create_interview(tests, language, timeframe_id)
    assign_identifier_and_signature(result)
    result = cat_mp_service.authentication(self)
    assign_cookies(result)
    cat_mp_service.initialize_interview(self)
    on_answer
  end

  def tests
    session.cat_mh_test_types.map do |test|
      { 'type' => test.short_name }
    end
  end

  def timeframe_id
    session.cat_mh_time_frame.timeframe_id
  end

  def language
    session.cat_mh_language.language_id
  end

  def assign_identifier_and_signature(result)
    return if result['status'] != 200

    signature = result['body']['interviews'].first['signature']
    identifier = result['body']['interviews'].first['identifier']
    update!(signature: signature, identifier: identifier)
  end

  def assign_cookies(result)
    return if result['cookies'].blank?

    jsession_id = result['cookies']['JSESSIONID']
    awselb = result['cookies']['AWSELB']
    update!(jsession_id: jsession_id, awselb: awselb)
  end

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
