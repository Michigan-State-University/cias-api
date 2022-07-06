# frozen_string_literal: true

class Session::Classic < Session
  has_many :question_groups, dependent: :destroy, inverse_of: :session, foreign_key: :session_id
  has_many :question_group_plains, dependent: :destroy, inverse_of: :session, class_name: 'QuestionGroup::Plain', foreign_key: :session_id
  has_one :question_group_finish, dependent: :destroy, inverse_of: :session, class_name: 'QuestionGroup::Finish', foreign_key: :session_id

  has_many :questions, through: :question_groups
  has_many :answers, dependent: :destroy, through: :questions

  after_commit :create_core_children, on: :create

  after_update_commit do
    SessionJobs::ReloadAudio.perform_later(id) if saved_change_to_attribute?(:google_tts_voice_id)
  end

  def integral_update
    return if published?

    propagate_settings
    save!
  end

  def first_question
    question_groups.where('questions_count > 0').order(:position).first.questions.includes(%i[image_blob image_attachment]).order(:position).first
  end

  def finish_screen
    question_group_finish.questions.first
  end

  def translate_questions(translator, source_language_name_short, destination_language_name_short)
    questions.each do |question|
      question.translate(translator, source_language_name_short, destination_language_name_short)
    end
  end

  def clear_speech_blocks
    questions.each(&:clear_audio)
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

  def propagate_settings
    return unless settings_changed?

    narrator = (settings['narrator'].to_a - settings_was['narrator'].to_a).to_h
    questions.each do |question|
      question.narrator['settings'].merge!(narrator)
      question.execute_narrator
      question.save!
    end
  end

  def user_session_type
    UserSession::Classic.name
  end

  def fetch_variables(filter_options = {})
    filtered = if filter_options[:allow_list].present?
                 questions.where(type: filter_options[:allow_list])
               else
                 questions.reorder('"question_groups"."position" ASC, "questions"."position" ASC')
               end
    target_question = questions.find_by(id: filter_options[:question_id])
    if target_question
      comparator = to_boolean(filter_options[:include_current_question]) ? '<=' : '<'
      filtered = filtered.where(question_group: target_question.question_group).where("questions.position #{comparator} ?", target_question.position)
    end
    filtered = filtered.where(type: digit_variable_questions) if filter_options[:only_digit_variables]
    filtered.map { |question| { subtitle: question.subtitle, variables: question.question_variables } }
  end

  def assign_google_tts_voice(first_session)
    intervention_language = intervention.google_language

    session_voice = first_session&.google_tts_voice
    if first_session.blank? || (first_session.present? && first_session.type.eql?('Session::CatMh') && !same_as_intervention_language(session_voice))
      self.google_tts_voice = intervention_language.default_google_tts_voice
    elsif first_session.present?
      self.google_tts_voice = first_session&.google_tts_voice
    end
  end

  private

  def to_boolean(value)
    ActiveRecord::Type::Boolean.new.cast(value)
  end

  def digit_variable_questions
    %w[Question::Single Question::Slider Question::Grid Question::Multiple]
  end

  def create_core_children
    return if question_group_finish

    qg_finish = ::QuestionGroup::Finish.new(session_id: id)
    qg_finish.save!
    ::Question::Finish.create!(question_group_id: qg_finish.id)
  end
end
