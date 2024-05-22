# frozen_string_literal: true

class Session::Sms < Session
  validates :question_group_finish, absence: true

  attribute :settings, :json, default: -> { { 'narrator' => { 'voice' => false, 'animation' => false } } }

  after_commit :create_core_children, on: :create

  def first_question
    question_groups.where('questions_count > 0').order(:position).first.questions.order(:position).first
  end

  def translate_questions(translator, source_language_name_short, destination_language_name_short)
    questions.each do |question|
      question.translate(translator, source_language_name_short, destination_language_name_short)
    end
  end

  def session_variables
    [].tap do |array|
      question_groups.each do |question_group|
        question_group.questions.each do |question|
          question.csv_header_names.each do |variable|
            array << variable
          end
        end
      end
    end
  end

  def user_session_type
    UserSession::Sms.name
  end

  def fetch_variables(filter_options = {}, filtered_question_id = nil)
    filtered = if filtered_question_id.present?
                 questions.where.not(id: filtered_question_id)
               else
                 questions
               end

    filtered = if filter_options[:allow_list].present?
                 filtered.where(type: filter_options[:allow_list])
               else
                 filtered.reorder('"question_groups"."position" ASC, "questions"."position" ASC')
               end
    target_question = questions.find_by(id: filter_options[:question_id])
    if target_question
      comparator = to_boolean(filter_options[:include_current_question]) ? '<=' : '<'
      question_group_position = target_question.question_group.position
      filtered = filtered.joins(:question_group).where("question_groups.position < ? OR
                                                        question_groups.position = ? AND questions.position #{comparator} ?",
                                                       question_group_position, question_group_position, target_question.position)
    end

    filtered = filtered.where(type: digit_variable_questions) if filter_options[:only_digit_variables]
    filtered.filter_map do |question|
      variables = present_variables(question.question_variables)
      { subtitle: question.subtitle, variables: variables } if variables.present?
    end
  end

  private

  def to_boolean(value)
    ActiveRecord::Type::Boolean.new.cast(value)
  end

  def digit_variable_questions
    %w[Question::Sms Question::SmsInformation]
  end

  def present_variables(variables)
    variables.filter(&:present?)
  end

  def create_core_children
    SmsCode.create!(session_id: id, sms_code: ('A'..'Z').to_a.sample(7).join) unless sms_codes.any?

    return if question_group_initial

    qg_initial = ::QuestionGroup::Initial.new(session_id: id)
    qg_initial.save!

    ::Question::SmsInformation.create!(question_group_id: qg_initial.id)
  end
end
