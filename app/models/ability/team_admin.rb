# frozen_string_literal: true

class Ability::TeamAdmin < Ability::Base
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
    can :manage, Session, intervention: { user_id: team_members_ids }
    can :create, Invitation
    can %i[read update destroy], Invitation, invitable_type: 'Session', invitable_id: Session.accessible_by(ability).ids
    can %i[read update destroy], Invitation, invitable_type: 'Intervention',
                                             invitable_id: Intervention.accessible_by(ability).ids
    can :manage, QuestionGroup, session: { intervention: { user_id: team_members_ids } }
    can :manage, Question, question_group: { session: { intervention: { user_id: team_members_ids } } }
    can :manage, Answer, question: { question_group: { session: { intervention: { user_id: team_members_ids } } } }
    can :manage, ReportTemplate, session: { intervention: { user_id: team_members_ids } }
    can :manage, ReportTemplate::Section,
        report_template: { session: { intervention: { user_id: team_members_ids } } }
    can :manage, ReportTemplate::Section::Variant,
        report_template_section: {
          report_template: { session: { intervention: { user_id: team_members_ids } } }
        }
    can :manage, SmsPlan, session: { intervention: { user_id: team_members_ids } }
    can :manage, SmsPlan::Variant, sms_plan: {
      session: { intervention: { user_id: team_members_ids } }
    }
    can :read, GeneratedReport,
        user_session: { session: { intervention: { user_id: team_members_ids } } }
    can :read, GoogleTtsLanguage
    can :read, GoogleTtsVoice
    can :read, GoogleLanguage
    can :get_user_answers, Answer, user_session: { session: { intervention: { user_id: team_members_ids } } }
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
    team_members_ids + team_members.researchers.flat_map { |researcher| participants_with_answers(researcher) }
  end
end
