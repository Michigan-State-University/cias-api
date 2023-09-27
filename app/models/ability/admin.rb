# frozen_string_literal: true

class Ability::Admin < Ability::Base
  include Ability::Generic::CollaboratorsAccess
  def definition
    super
    admin if role?(class_name)
  end

  private

  def admin
    can :manage, :all
    cannot :get_protected_attachment, Intervention do |intervention|
      intervention.user_id != user.id
    end
    cannot :get_protected_attachment, GeneratedReport do |report|
      report.user_session.session.intervention.user_id != user.id
    end
    cannot :clear_protected_intervention, Intervention do |intervention|
      intervention.user_id != user.id
    end
    cannot :manage, GeneratedReport
    can :manage, GeneratedReport, user_session: { session: { intervention: { user_id: user.id } } }
    enable_data_access(user)
  end
end
