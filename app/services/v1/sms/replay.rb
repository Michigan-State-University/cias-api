# frozen_string_literal: true

class V1::Sms::Replay
  attr_reader :from_number, :to_number, :message

  def self.call(from, to, body)
    new(from, to, body).call
  end

  def initialize(from, to, body)
    @from_number = from
    @to_number = to
    @message = body.to_s.strip
    @number_prefix = Phonelib.parse(from).country_code
    @national_number = Phonelib.parse(from).national(false)
  end

  def call
    # Handle case with SMS stop signal
    if message.downcase.match?('stop')
      delete_messaged_for(from_number)
      return response_message
    end

    # Handle incoming message
    if message.length >= SmsCode::SMS_CODE_MIN_LENGTH
      handle_message_with_sms_code
    else
      handle_message_with_answer
    end

    response_message
  end

  private

  def response_message
    @response_message ||= Twilio::TwiML::MessagingResponse.new
  end

  def translate_with_intervention_locale(session, key)
    I18n.with_locale(session.intervention.google_language&.language_code) { I18n.t(key) }
  end

  def delete_messaged_for(number)
    @user = User.left_joins(:phone).find_by(phone: { prefix: "+#{@number_prefix}", number: @national_number })

    if @user
      sms_sessions = UserSession::Sms.where(user_id: @user.id).update(finished_at: DateTime.current)
      sms_session_ids = sms_sessions.pluck(:id)

      queue = Sidekiq::ScheduledSet.new
      queue.each do |job|
        job_args = job.args.first
        job.delete if job_args['job_class'] == 'UserSessionJobs::ScheduleDailyMessagesJob' && sms_session_ids.include?(job_args['arguments'].first)
        job.delete if job_args['job_class'] == 'UserSessionJobs::SendQuestionSmsJob' && job_args['arguments'].first.eql?(@user.id)
      end
    end

    queue = Sidekiq::ScheduledSet.new
    queue.each do |job|
      job_args = job.args.first
      job.delete if job_args['job_class'] == 'SmsPlans::SendSmsJob' && job_args['arguments'].first.eql?(number)
    end
  end

  def handle_message_with_sms_code
    session = SmsCode.find_by(sms_code: message)&.session
    return SmsPlans::SendSmsJob.perform_later(from_number, I18n.t('sms.session_not_found'), nil, nil) unless session

    user_intervention_ids = session.intervention.user_intervention_ids
    possible_user_ids = User.left_joins(:phone).where(phone: { prefix: "+#{@number_prefix}", number: @national_number }).pluck(:id)
    @user = UserIntervention.find_by(id: user_intervention_ids, user_id: possible_user_ids)&.user

    if @user
      user_session = UserSession::Sms.find_by(session_id: session.id, user_id: @user.id)

      if user_session
        SmsPlans::SendSmsJob.perform_later(@user.full_number, translate_with_intervention_locale(session, 'sms.already_signed'), nil, @user.id)
      elsif @user.user_sessions.where(type: 'UserSession::Sms').where.not(finished_at: nil).any?
        SmsPlans::SendSmsJob.perform_later(@user.full_number, translate_with_intervention_locale(session, 'sms.cannot_assign_to_many_campaigns'), nil,
                                           @user.id)
      else
        create_new_user_session!(session: session, user: @user)
      end
    else
      user = V1::Users::CreateGuest.call(from_number)
      create_new_user_session!(session: session, user: user)
    end
  end

  def handle_message_with_answer
    @users = User.left_joins(:phone).where(phone: { prefix: "+#{@number_prefix}", number: @national_number })
    if @users
      user_session = UserSession::Sms.left_joins(:user)
                                     .where(user_id: @users.pluck(:id),
                                            finished_at: nil,
                                            user: { pending_sms_answer: true })
                                     .where.not(current_question_id: nil)
                                     .first
      if user_session
        @user = user_session.user
        unless user_session.current_question_id
          default_response = user_session.session.default_response
          SmsPlans::SendSmsJob.perform_later(@user.full_number,
                                             # rubocop:disable Metrics/BlockNesting
                                             if default_response.empty?
                                               # rubocop:enable Metrics/BlockNesting
                                               translate_with_intervention_locale(user_session.session, 'sms.wrong_message')
                                             else
                                               user_session.session.default_response
                                             end,
                                             nil,
                                             @user.id)
          return
        end

        question = Question.find(user_session.current_question_id)

        is_answer_correct = validate_answer_for_question?(question, message)

        if is_answer_correct
          V1::AnswerService.call(@user, user_session.id, question.id,
                                 { type: 'Answer::Sms', body: { data: [{ value: message, var: question.body['variable']['name'] }] } })
          @user.update(pending_sms_answer: false)
          remove_question_followups(@user, question, user_session)
          recalculate_questions_to_be_send(user_session)
        elsif question.accepted_answers['answer_if_wrong']
          SmsPlans::SendSmsJob.perform_later(@user.full_number, question.accepted_answers['answer_if_wrong'], nil,
                                             @user.id)
        end
      else
        SmsPlans::SendSmsJob.perform_later(from_number, I18n.t('sms.wrong_message'), nil, nil)
      end
    else
      SmsPlans::SendSmsJob.perform_later(from_number, I18n.t('sms.wrong_message'), nil, nil)
    end
  end

  def remove_question_followups(user, question, user_session)
    queue = Sidekiq::ScheduledSet.new
    queue.each do |job|
      job_args = job.args.first
      job.delete if job_args['job_class'] == 'UserSessionJobs::SendQuestionSmsJob' && job_args['arguments'].eql?([user.id, question.id, user_session.id, true])
    end
  end

  def recalculate_questions_to_be_send(user_session)
    queue = Sidekiq::ScheduledSet.new
    queue.each do |job|
      job_args = job.args.first
      if job_args['job_class'] == 'UserSessionJobs::SendQuestionSmsJob' &&
         job_args['arguments'][2].eql?(user_session.id) &&
         job_args['arguments'][4].eql?(false)
        job.delete
      end
      job.delete if job_args['job_class'] == 'UserSessionJobs::ScheduleDailyMessagesJob' && job_args['arguments'][0].eql?(user_session.id)
    end
    schedule_user_session_job!(user_session)
  end

  def create_new_user_session!(session:, user:)
    health_clinic_id = session.intervention.organization_id ? session.sms_code.health_clinic_id : nil
    user_session = V1::UserSessions::CreateService.call(session.id, user.id, health_clinic_id)
    user_session.save!
    schedule_user_session_job!(user_session)
    SmsPlans::SendSmsJob.perform_later(user.full_number, user_session.session.welcome_message, nil, user.id) if user_session.session.welcome_message.present?
  end

  def schedule_user_session_job!(user_session)
    UserSessionJobs::ScheduleDailyMessagesJob.perform_later(user_session.id)
  end

  def validate_answer_for_question?(question, answer)
    accepted_answers = question.accepted_answers
    return true if question.accepted_answers.blank?

    if accepted_answers['predefined']
      accepted_answers['predefined'].include?(answer)
    else
      (accepted_answers['range']['from'].to_i..accepted_answers['range']['to'].to_i).to_a.map(&:to_s).include?(answer)
    end
  end
end
