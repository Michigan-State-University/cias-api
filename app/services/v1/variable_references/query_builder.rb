# frozen_string_literal: true

module V1::VariableReferences::QueryBuilder
  private

  def build_question_base_query(session, exclude_source_session)
    @question_base_query ||= {}
    key = [session.id, exclude_source_session]
    @question_base_query[key] ||= if exclude_source_session
                                    Question.joins(question_group: { session: :intervention })
                                            .where(interventions: { id: session.intervention_id })
                                            .where.not(question_groups: { session_id: session.id })
                                  else
                                    Question.joins(:question_group)
                                            .where(question_groups: { session_id: session.id })
                                  end
  end

  def build_question_group_base_query(session, exclude_source_session)
    @question_group_base_query ||= {}
    key = [session.id, exclude_source_session]
    @question_group_base_query[key] ||= if exclude_source_session
                                          QuestionGroup.joins(session: :intervention)
                                                      .where(interventions: { id: session.intervention_id })
                                                      .where.not(session_id: session.id)
                                                      .where.not(formulas: nil)
                                        else
                                          QuestionGroup.where(session_id: session.id)
                                                      .where.not(formulas: nil)
                                        end
  end

  def build_session_base_query(session, exclude_source_session)
    @session_base_query ||= {}
    key = [session.id, exclude_source_session]
    @session_base_query[key] ||= if exclude_source_session
                                   Session.where(intervention_id: session.intervention_id)
                                          .where.not(id: session.id)
                                 else
                                   Session.where(id: session.id)
                                 end
  end

  def build_report_template_section_base_query(session, exclude_source_session)
    @report_template_section_base_query ||= {}
    key = [session.id, exclude_source_session]
    @report_template_section_base_query[key] ||= if exclude_source_session
                                                   ReportTemplate::Section.joins(report_template: { session: :intervention })
                                                                         .where(interventions: { id: session.intervention_id })
                                                                         .where.not(sessions: { id: session.id })
                                                 else
                                                   ReportTemplate::Section.joins(report_template: :session)
                                                                         .where(sessions: { id: session.id })
                                                 end
  end

  def build_report_template_variant_base_query(session, exclude_source_session)
    @report_template_variant_base_query ||= {}
    key = [session.id, exclude_source_session]
    @report_template_variant_base_query[key] ||= if exclude_source_session
                                                   ReportTemplate::Section::Variant.joins(
                                                     report_template_section: { report_template: { session: :intervention } }
                                                   )
                                                                                   .where(interventions: { id: session.intervention_id })
                                                                                   .where.not(sessions: { id: session.id })
                                                 else
                                                   ReportTemplate::Section::Variant.joins(report_template_section: { report_template: :session })
                                                                                   .where(sessions: { id: session.id })
                                                 end
  end

  def build_sms_plan_base_query(session, exclude_source_session)
    @sms_plan_base_query ||= {}
    key = [session.id, exclude_source_session]
    @sms_plan_base_query[key] ||= if exclude_source_session
                                    SmsPlan.joins(session: :intervention)
                                           .where(interventions: { id: session.intervention_id })
                                           .where.not(sessions: { id: session.id })
                                  else
                                    SmsPlan.where(session_id: session.id)
                                  end
  end
end
