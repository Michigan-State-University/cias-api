# frozen_string_literal: true

module Clone::SessionVariableNaming
  private

  def cloned_session_variable(session)
    base = "cloned_#{clone_stem(session.variable)}_#{session.position}"
    return base unless session_variable_taken?(base)

    suffix = 2
    suffix += 1 while session_variable_taken?("#{base}_#{suffix}")
    "#{base}_#{suffix}"
  end

  # Stops repeated duplication stacking prefixes - `cloned_cloned_s2077_3_3` exists in real data.
  def clone_stem(variable)
    stem = variable.to_s
    stem = Regexp.last_match(1) while stem =~ /\Acloned_(.+)_\d+\z/
    stem
  end

  # Org scope, and the SOURCE's: `V1::ChartStatistics::CreateForUserSessions` matches participants by
  # `sessions.variable` across the whole organization, and `clear_organization!` has already blanked
  # the outcome's.
  def session_variable_taken?(variable)
    scope = ::Session.joins(:intervention).where(variable: variable)

    return scope.exists?(interventions: { id: [source.id, outcome.id] }) if source.organization_id.blank?

    scope.exists?(['interventions.organization_id = :org OR interventions.id IN (:ids)',
                   { org: source.organization_id, ids: [source.id, outcome.id] }])
  end
end
