# frozen_string_literal: true

class V1::FlowService::CatMh::NextQuestion
  include CatMh::QuestionMapping

  def initialize(user_session)
    @user_session = user_session
  end

  attr_accessor :user_session

  def call
    cat_mh_question = cat_mh_api.get_next_question(user_session)
    verify!(cat_mh_question)

    user_session.finish if cat_mh_question['body']['questionID'] == -1
    question = prepare_question(user_session, cat_mh_question['body'])

    schedule_service.call(question)
  end

  delegate :additional_information, to: :schedule_service

  private

  def schedule_service
    @schedule_service ||= V1::FlowService::ScheduleService.new(user_session)
  end

  def cat_mh_api
    @cat_mh_api ||= Api::CatMh.new
  end

  def verify!(question)
    raise_cat_mh_error if question['status'] != 200
  end

  def raise_cat_mh_error
    raise CatMh::ConnectionFailedException.new(
      I18n.t('activerecord.errors.models.intervention.attributes.cat_mh_connection_failed.title'),
      I18n.t('activerecord.errors.models.intervention.attributes.cat_mh_connection_failed.body'),
      I18n.t('activerecord.errors.models.intervention.attributes.cat_mh_connection_failed.button')
    )
  end
end
