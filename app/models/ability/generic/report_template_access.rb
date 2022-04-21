# frozen_string_literal: true

module Ability::Generic::ReportTemplateAccess
  def enable_report_template_access(ids)
    can :manage, ReportTemplate, session: { intervention: { user_id: ids } }
    can :manage, ReportTemplate::Section, report_template: { session: { intervention: { user_id: ids } } }
    can :manage, ReportTemplate::Section::Variant, report_template_section: { report_template: { session: { intervention: { user_id: ids } } } }
  end
end
