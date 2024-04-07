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
    @user = User.left_joins(:phone).find_by(phone: { prefix: "+#{@number_prefix}", number: @national_number })
  end

  def call
    # Handle case with SMS stop signal
    if message.downcase.match?('stop')
      delete_messaged_for(from_number)
      return response_message
    end

    # Handle incoming message
    if message.length >= Session::Sms::SMS_CODE_MIN_LENGTH
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

  def delete_messaged_for(number)
    queue = Sidekiq::ScheduledSet.new
    queue.each do |job|
      job_args = job.args.first
      job.delete if job_args['job_class'] == 'SmsPlans::SendSmsJob' && job_args['arguments'].first.eql?(number)
    end
  end

  def handle_message_with_sms_code
    session = Session::Sms.find_by(sms_code: message)
    return SmsPlans::SendSmsJob.perform_later(from_number, 'There is no such session', nil, @user&.id) unless session

    if @user
      user_session = UserSession::Sms.find_by(session_id: session.id, user_id: @user.id)

      if user_session
        SmsPlans::SendSmsJob.perform_later(@user.full_number, 'You are already signed to this session', nil, @user.id)
      else
        user_session = create_new_user_session!(session: session, user: @user)
        handle_next_question(user_session: user_session)
      end
    else
      user = V1::Users::CreateGuest.call(from_number)
      user_session = create_new_user_session!(session: session, user: user)
      handle_next_question(user_session: user_session)
    end
  end

  def handle_message_with_answer
    if @user
      user_session = UserSession::Sms.find_by(user_id: @user.id)
      if user_session
        question = V1::FlowService::NextQuestion.new(user_session).call(nil)

        unless question
          SmsPlans::SendSmsJob.perform_later(@user.full_number, 'Wrong message', nil, nil)
          return
        end

        V1::AnswerService.call(@user, user_session.id, question.id,
                               { type: 'Answer::Sms', body: { data: [{ value: message, var: question.body['variable']['name'] }] } })
        handle_next_question(user_session: user_session)
      else
        SmsPlans::SendSmsJob.perform_later(@user.full_number, 'Wrong message', nil, nil)
      end
    else
      SmsPlans::SendSmsJob.perform_later(from_number, 'Wrong message', nil, nil)
    end
  end

  def handle_next_question(user_session:)
    user = user_session.user
    question = V1::FlowService::NextQuestion.new(user_session).call(nil)
    handle_sms_question_in_session(user_session: user_session, question: question, user: user) if question
  end

  def handle_sms_question_in_session(user_session:, question:, user:)
    # rubocop:disable Style/IdenticalConditionalBranches
    if question.type.match?('Question::SmsInformation')
      SmsPlans::SendSmsJob.perform_later(user.full_number, question.title, nil, user.id)
      V1::AnswerService.call(user, user_session.id, question.id, { type: 'Answer::SmsInformation', body: { data: [] } })
      next_question = V1::FlowService::NextQuestion.new(user_session).call(nil)
      SmsPlans::SendSmsJob.perform_later(user.full_number, next_question.title, nil, user.id) if next_question
    else
      SmsPlans::SendSmsJob.perform_later(user.full_number, question.title, nil, user.id)
    end
    # rubocop:enable Style/IdenticalConditionalBranches
  end

  def create_new_user_session!(session:, user:)
    user_session = V1::UserSessions::CreateService.call(session.id, user.id, nil)
    user_session.save!
    user_session
  end
end
