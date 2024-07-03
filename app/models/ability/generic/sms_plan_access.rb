# frozen_string_literal: true

module Ability::Generic::SmsPlanAccess
  def enable_sms_plan_access(session_path)
    can :manage, SmsPlan, session: session_path
    can :manage, SmsPlan::Variant, sms_plan: { session: session_path }
    can :manage, SmsLink, session: session_path
  end
end
