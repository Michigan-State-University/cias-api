# frozen_string_literal: true

class Api::CatMh
  def create_interview(tests, language, timeframe_id, application_id, organization_id, subject_id = 'test_subject', number_of_interventions = 1) # rubocop:disable Metrics/ParameterLists
    Api::CatMh::CreateInterview.call(subject_id, number_of_interventions, application_id, organization_id, tests, language, timeframe_id)
  end

  def status(user_session)
    interview_id = user_session.cat_interview_id
    identifier = user_session.identifier
    signature = user_session.signature
    intervention = user_session.session.intervention
    organization_id = intervention.cat_mh_organization_id
    application_id = intervention.cat_mh_application_id

    Api::CatMh::CheckStatus.call(interview_id, identifier, signature, application_id, organization_id)
  end

  def authentication(user_session)
    identifier = user_session.identifier
    signature = user_session.signature

    Api::CatMh::Authentication.call(identifier, signature)
  end

  def initialize_interview(user_session)
    response = Api::CatMh::InitializeInterview.call(jsession_id(user_session), awselb(user_session))

    if error?(response)
      fix_problem(response, user_session)
      response = Api::CatMh::InitializeInterview.call(jsession_id(user_session), awselb(user_session))
    end

    response
  end

  def get_next_question(user_session)
    response = Api::CatMh::Question.call(jsession_id(user_session), awselb(user_session))

    if error?(response)
      fix_problem(response, user_session)
      response = Api::CatMh::Question.call(jsession_id(user_session), awselb(user_session))
      if blocked_cookies?(response)
        reset_cookies(jsession_id(user_session), awselb(user_session))
        response = Api::CatMh::Question.call(jsession_id(user_session), awselb(user_session))
      end
    end

    response
  end

  def on_user_answer(user_session, question_id, response, duration)
    response = Api::CatMh::Answer.call(jsession_id(user_session), awselb(user_session), question_id, response, duration)

    if error?(response)
      fix_problem(response, user_session)
      response = Api::CatMh::Answer.call(jsession_id(user_session), awselb(user_session), question_id, response, duration)
    end

    response
  end

  def get_result(user_session)
    response = Api::CatMh::Result.call(jsession_id(user_session), awselb(user_session))

    if error?(response)
      fix_problem(response, user_session)
      response = Api::CatMh::Result.call(jsession_id(user_session), awselb(user_session))
    end

    response
  end

  def terminate_intervention(user_session)
    Api::CatMh::TerminateSession.call(jsession_id(user_session), awselb(user_session))
  end

  def reset_cookies(jsession_id, awselb)
    Api::CatMh::BreakLock.call(jsession_id, awselb)
  end

  def jsession_id(user_session)
    user_session.jsession_id
  end

  def awselb(user_session)
    user_session.awselb
  end

  def fix_problem(response, user_session)
    if blocked_cookies?(response)
      reset_cookies(jsession_id(user_session), awselb(user_session))
    elsif session_time_out?(response)
      new_cookies = authentication(user_session)
      new_jsession_id = new_cookies['cookies']['JSESSIONID']
      new_awselb = new_cookies['cookies']['AWSELB']
      user_session.update!(jsession_id: new_jsession_id, awselb: new_awselb)
    end
  end

  def blocked_cookies?(response)
    response['error'].eql?("#{ENV.fetch('BASE_CAT_URL', nil)}/interview/secure/errorInProgress.html")
  end

  def session_time_out?(response)
    response['error'].eql?('Request Time-out')
  end

  def error?(response)
    response['status'] == 400
  end
end
