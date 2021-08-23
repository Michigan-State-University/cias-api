# frozen_string_literal: true

class Api::CatMh
  def create_interview(subject_id, number_of_interventions, tests, language)
    Api::CatMh::CreateInterview.call(subject_id, number_of_interventions, tests, language)
  end

  def status(interview_id, identifier, signature)
    Api::CatMh::CheckStatus.call(interview_id, identifier, signature)
  end

  def authentication(identifier, signature)
    Api::CatMh::Authentication.call(identifier, signature)
  end

  def initialize_interview(jsession_id, awselb)
    Api::CatMh::InitializeInterview.call(jsession_id, awselb)
  end

  def question(jsession_id, awselb)
    Api::CatMh::Question.call(jsession_id, awselb)
  end

  def answer(jsession_id, awselb, question_id, response, duration)
    Api::CatMh::Answer.call(jsession_id, awselb, question_id, response, duration)
  end

  def result(jsession_id, awselb)
    Api::CatMh::Result.call(jsession_id, awselb)
  end

  def terminate_intervention(jsession_id, awselb)
    Api::CatMh::TerminateSession.call(jsession_id, awselb)
  end
end
