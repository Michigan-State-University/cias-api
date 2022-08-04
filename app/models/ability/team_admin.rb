# frozen_string_literal: true

class Ability::TeamAdmin < Ability::Base
  include Ability::Generic::GoogleAccess
  include Ability::Generic::ReportTemplateAccess
  include Ability::Generic::SmsPlanAccess
  include Ability::Generic::QuestionAccess
  include Ability::Generic::CatMhAccess

  def definition
    super
    team_admin if role?(class_name)
  end

  private

  def team_admin
    can %i[read update invite_researcher remove_researcher], Team, team_admin_id: user.id
    can %i[read update active], User, id: team_members_and_researchers_participants
    can :create, :preview_session_user
    can :list_researchers, User, team_id: team_admin_teams_ids

    can :manage, Intervention, user_id: team_members_ids
    can :manage, UserSession, session: { intervention: { user_id: team_members_ids } }
    can :read, UserIntervention, intervention: { user_id: team_members_ids }
    can :manage, Session, intervention: { user_id: team_members_ids }
    can :create, Invitation
    can :read_cat_resources, User
    can %i[read update destroy], Invitation, invitable_type: 'Session', invitable_id: Session.accessible_by(ability).ids
    can %i[read update destroy], Invitation, invitable_type: 'Intervention',
                                             invitable_id: Intervention.accessible_by(ability).ids
    can :manage, InterventionAccess, intervention: { user_id: user.id }

    enable_questions_access(team_members_ids)
    enable_report_template_access(team_members_ids)
    enable_sms_plan_access({ intervention: { user_id: team_members_ids } })
    enable_cat_mh_access

    can :read, GeneratedReport,
        user_session: { session: { intervention: { user_id: team_members_ids } } }
    can :create, DownloadedReport,
        generated_report: { user_session: { session: { intervention: { user_id: team_members_ids } } } }

    can :get_user_answers, Answer, user_session: { session: { intervention: { user_id: team_members_ids } } }
    enable_google_access
  end

  def team_members_ids
    @team_members_ids ||= team_members.pluck(:id)
  end

  def team_members
    @team_members ||= User.where('team_id in (?) OR id=?', team_admin_teams_ids, user.id)
  end

  def team_admin_teams_ids
    @team_admin_teams_ids ||= Team.where(team_admin_id: user.id).pluck(:id)
  end

  def team_members_and_researchers_participants
    team_members_ids + team_members.with_intervention_creation_access.flat_map { |researcher| participants_with_answers(researcher) }
  end
end
