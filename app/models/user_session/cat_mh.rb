# frozen_string_literal: true

class UserSession::CatMh < UserSession
  include ::CatMh::QuestionMapping

  after_create_commit :initialize_user_session

  def on_answer
    update(last_answer_at: DateTime.current)
  end

  def finish(send_email: true)
    return if finished_at

    update(finished_at: DateTime.current)

    cat_mh_api = Api::CatMh.new

    result = cat_mh_api.get_result(self)
    result_to_answers(result['body']) if result['status'] == 200
    cat_mh_api.terminate_intervention(self)

    GenerateUserSessionReportsJob.perform_later(id)

    V1::SmsPlans::ScheduleSmsForUserSession.call(self)
    V1::UserSessionScheduleService.new(self).schedule if send_email
    V1::ChartStatistics::CreateForUserSession.call(self)
    update_user_intervention(session_is_finished: true)
  end

  def first_question
    question = Api::CatMh.new.get_next_question(self)

    prepare_question(self, question['body'])
  end

  private

  def initialize_user_session
    cat_mp_service = Api::CatMh.new
    intervention = session.intervention

    cat_mh_organization_id = intervention.cat_mh_organization_id
    cat_mh_application_id = intervention.cat_mh_application_id
    result = cat_mp_service.create_interview(tests, language, timeframe_id, cat_mh_application_id, cat_mh_organization_id, user.id.delete('-'))

    intervention.update!(created_cat_mh_session_count: (intervention.created_cat_mh_session_count + 1))

    assign_basic_information(result)
    result = cat_mp_service.authentication(self)
    assign_cookies(result)
    cat_mp_service.initialize_interview(self)
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

  def assign_basic_information(result)
    return if result['status'] != 200

    signature = result['body']['interviews'].first['signature']
    identifier = result['body']['interviews'].first['identifier']
    interview_id = result['body']['interviews'].first['interviewID']
    update!(signature: signature, identifier: identifier, cat_interview_id: interview_id)
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
