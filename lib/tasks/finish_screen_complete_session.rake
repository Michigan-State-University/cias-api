# frozen_string_literal: true

namespace :finish_screen do
  desc 'Switch finish screens of module interventions to "Complete Session" (INTERVENTION_IDS=uuid,uuid)'
  task complete_session: :environment do
    intervention_ids = ENV.fetch('INTERVENTION_IDS', '').downcase.split(',').map(&:strip).reject(&:empty?)
    abort 'INTERVENTION_IDS is required' if intervention_ids.empty?

    interventions = Intervention.where(id: intervention_ids)
    missing = intervention_ids - interventions.map(&:id)
    abort "Interventions not found: #{missing.join(', ')}" if missing.any?

    not_module = interventions.reject(&:module_intervention?)
    abort "Not module interventions: #{not_module.map(&:id).join(', ')}" if not_module.any?

    interventions.each do |intervention|
      finish_screens = Question::Finish.joins(question_group: :session).where(sessions: { intervention_id: intervention.id })
      finish_screens.find_each do |finish_screen|
        finish_screen.update!(settings: finish_screen.settings.merge('show_dashboard_button' => false))
      end

      p "Updated #{finish_screens.count} finish screens of intervention #{intervention.id} (#{intervention.name})"
    end
  end
end
