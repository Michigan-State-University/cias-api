# frozen_string_literal: true

class Ability::TeamAdmin < Ability::Base
  def definition
    super
    team_admin if role?(class_name)
  end

  private

  def team_admin
    can %i[read update invite_researcher remove_researcher], Team, id: user.team_id
    can %i[read update active], User, team_id: user.team_id

    can :manage, Intervention, user_id: team_members_ids
    can :manage, UserSession, session: { intervention: { user_id: team_members_ids } }
    can :manage, Session, intervention: { user_id: team_members_ids }
    can :create, Invitation
    can %i[read update destroy], Invitation, invitable_type: 'Session', invitable_id: Session.accessible_by(ability).ids
    can %i[read update destroy], Invitation, invitable_type: 'Intervention', invitable_id: Intervention.accessible_by(ability).ids
    can :manage, QuestionGroup, session: { intervention: { user_id: team_members_ids } }
    can :manage, Question, question_group: { session: { intervention: { user_id: team_members_ids } } }
    can :manage, Answer, question: { question_group: { session: { intervention: { user_id: team_members_ids } } } }
    can :manage, ReportTemplate, session: { intervention: { user_id: team_members_ids } }
    can :manage, ReportTemplate::Section,
        report_template: { session: { intervention: { user_id: team_members_ids } } }
  end

  def team_members_ids
    @team_members_ids ||= user.team.user_ids
  end
end
