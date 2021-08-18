# frozen_string_literal: true

class Session::Classic < Session
  has_many :question_groups, dependent: :destroy, inverse_of: :session, foreign_key: :session_id
  has_many :question_group_plains, dependent: :destroy, inverse_of: :session, class_name: 'QuestionGroup::Plain', foreign_key: :session_id
  has_one :question_group_finish, dependent: :destroy, inverse_of: :session, class_name: 'QuestionGroup::Finish', foreign_key: :session_id

  has_many :questions, dependent: :destroy, through: :question_groups
  has_many :answers, dependent: :destroy, through: :questions

  after_commit :create_core_children, on: :create

  after_update_commit do
    SessionJobs::ReloadAudio.perform_later(id) if saved_change_to_attribute?(:google_tts_voice_id)
  end

  def first_question
    question_groups.where('questions_count > 0').order(:position).first.questions.order(:position).first
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

  private

  def create_core_children
    return if question_group_finish

    qg_finish = ::QuestionGroup::Finish.new(session_id: id)
    qg_finish.save!
    ::Question::Finish.create!(question_group_id: qg_finish.id)
  end
end
