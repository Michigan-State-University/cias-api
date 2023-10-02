# frozen_string_literal: true

class V1::QuestionGroup::ShareExternallyService
  include InvitationInterface

  def self.call(researcher_emails, source_session_id, selected_groups_with_questions, current_user)
    new(researcher_emails, source_session_id, selected_groups_with_questions, current_user).call
  end

  def initialize(researcher_emails, source_session_id, selected_groups_with_questions, current_user)
    @researcher_emails = researcher_emails
    @researchers = []
    @source_session = Session.accessible_by(current_user.ability).find(source_session_id)
    @selected_groups_with_questions = selected_groups_with_questions
    @current_user = current_user
  end

  def call
    init_researchers
    ActiveRecord::Base.transaction do
      researchers.each do |researcher|
        check_if_user_has_correct_ability(researcher)

        new_intervention = researcher.interventions.create!(name: title_for_intervention)
        new_session = Session.create!(name: I18n.t('duplication_with_structure.session_name'), intervention: new_intervention)
        V1::QuestionGroup::DuplicateWithStructureService.call(new_session, selected_groups_with_questions)

        CloneMailer.cloned_question_group_activate(researcher, new_intervention.name).deliver_now unless researcher.confirmed?
      end
    end
  end

  attr_reader :researchers, :current_user, :selected_groups_with_questions, :source_session

  private

  def init_researchers
    _existing_emails, non_existing_emails = split_emails_exist(@researcher_emails)
    invite_non_existing_users(non_existing_emails, true, [:researcher])
    @researchers = User.where(email: @researcher_emails.map(&:downcase))
  end

  def title_for_intervention
    I18n.t('duplication_with_structure.intervention_name', source_intervention_name: source_session.intervention.name,
                                                           user_full_name: "#{current_user.first_name} #{current_user.last_name}")
  end

  def check_if_user_has_correct_ability(user)
    raise CanCan::AccessDenied, I18n.t('duplication_with_structure.not_researcher') unless user.ability.can? :manage, Intervention
  end
end
