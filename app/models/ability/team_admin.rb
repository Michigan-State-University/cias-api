# frozen_string_literal: true

class Ability::TeamAdmin < Ability::Base
  def definition
    super
    team_admin if role?(class_name)
  end

  private

  def team_admin
    can %i[read update invite_researcher remove_researcher], Team, id: user.team_id
    can %i[read update active], User, id: team_members_and_researchers_participants
    can :create, :preview_session_user

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
    can :manage, ReportTemplate::Section::Variant,
        report_template_section: {
          report_template: { session: { intervention: { user_id: team_members_ids } } }
        }
    can :manage, SmsPlan, session_id: team_session_ids
    can :manage, SmsPlan::Variant, sms_plan: { session_id: team_session_ids }
  end

  def team_members_ids
    @team_members_ids ||= user.team.user_ids
  end

  def team_members_and_researchers_participants
    members_ids = team_members_ids
    User.where(id: members_ids).researchers.each do |researcher|
      members_ids << participants_with_answers(researcher)
    end
    members_ids
  end

  def team_session_ids
    Session.joins(:intervention).where(interventions: { user_id: team_members_ids }).select(:id)
  end
end
