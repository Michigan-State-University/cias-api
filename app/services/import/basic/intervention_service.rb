# frozen_string_literal: true

class Import::Basic::InterventionService
  include ImportOperations

  def self.call(user_id, intervention_hash)
    new(
      user_id,
      intervention_hash.except(:version)
    ).call
  end

  def initialize(user_id, intervention_hash)
    @user = User.find(user_id)
    @logo = intervention_hash.delete(:logo)
    @sessions_hash = intervention_hash.delete(:sessions)
    @intervention_hash = intervention_hash
  end

  attr_reader :user, :logo, :intervention_hash, :sessions_hash
  attr_accessor :intervention

  def call
    accesses = intervention_hash.delete(:intervention_accesses)
    @intervention = Intervention.create!(intervention_hash.merge({ user_id: user.id, google_language: google_language, logo: import_file(logo) }))
    add_logo_description! if logo.present?

    accesses&.each do |intervention_access_hash|
      get_import_service_class(intervention_access_hash, InterventionAccess).call(intervention.id, intervention_access_hash)
    end

    sessions_hash&.each do |session_hash|
      get_import_service_class(session_hash, Session).call(intervention.id, session_hash)
    end

    set_branching_and_reflections!
    create_email_and_notification!

    intervention
  end

  private

  def google_language
    return @google_language if defined?(@google_language)

    @google_language = GoogleLanguage.find_by(
      language_name: intervention_hash.delete(:language_name),
      language_code: intervention_hash.delete(:language_code)
    )
  end

  def add_logo_description!
    intervention.logo_blob&.update!(description: logo[:description])
  end

  def set_branching_and_reflections!
    sessions = Session.where(intervention_id: intervention.id)
    sessions.each do |session|
      handle_session_branching!(session, sessions)
    end

    questions = Question.joins(question_group: :session).where(question_groups: { sessions: { intervention_id: intervention.id } })
    questions.each do |question|
      handle_branching!(question, questions)
      handle_reflections!(question, questions)
    end
  end

  def create_email_and_notification!
    create_notification!

    return unless user.email_notification

    ImportMailer.result(user, intervention).deliver_now
  end

  def handle_branching!(target_question, questions)
    sessions = intervention.sessions
    target_question.formulas.each do |formula|
      formula['patterns'].each do |pattern|
        pattern['target'].each do |target|
          if target['type'].start_with?('Question')
            location = object_location(target)
            target_id = find_question_id(questions, target_question, location)
            target['id'] = target_id if target_id.present?
          elsif target['type'].start_with?('Session')
            target_location = object_location(target)
            session_id = sessions.find_by(position: target_location[:object_position])&.id
            target['id'] = session_id if session_id.present?
          end
        end
      end
    end
    target_question.save!
  end

  def handle_reflections!(target_question, questions)
    target_question.narrator['blocks'].each do |block|
      next unless block['type'] == 'Reflection'

      location = object_location(block, 'question_id')
      target_id = find_question_id(questions, target_question, location)
      block['question_id'] = target_id if target_id.present?
      target_question.save!
    end
  end

  def handle_session_branching!(target_session, sessions)
    target_session.formulas.each do |formula|
      formula['patterns'].each do |pattern|
        pattern['target'].each do |target|
          target_location = object_location(target)
          session_id = sessions.find_by(position: target_location[:object_position])&.id
          target['id'] = session_id if session_id.present?
        end
      end
    end
    target_session.save!
  end

  def object_location(target, target_key = 'id')
    questions_branching = sessions_hash.flat_map { |s| s[:question_groups].flat_map { |qg| qg[:questions].flat_map { |q| q[:relations_data] } } }
    sessions_branching = sessions_hash.flat_map { |s| s[:relations_data] }
    branching_locations = questions_branching + sessions_branching
    branching_locations.detect { |branch_location| branch_location[:id] == target[target_key] } || {}
  end

  def find_question_id(scope, question_in_scope, location)
    return if location.nil?

    scope.joins(:question_group)
             .where(question_group: { position: location[:question_group_position], session_id: question_in_scope.question_group.session.id })
             .find_by(position: location[:object_position])&.id
  end

  def create_notification!
    Notification.create!(user: user, notifiable: intervention, event: :successfully_restored_intervention, data: generate_notification_body)
  end

  def generate_notification_body
    {
      intervention_name: intervention.name,
      intervention_id: intervention.id
    }
  end
end
