# frozen_string_literal: true

namespace :finish_screen do
  desc 'Switch finish screens of module interventions to "Complete Session" (INTERVENTION_IDS=uuid,uuid). ' \
       'DRY_RUN=1 previews.'
  task complete_session: :environment do
    intervention_ids = ENV.fetch('INTERVENTION_IDS', '').downcase.split(',').map(&:strip).reject(&:empty?)
    abort 'INTERVENTION_IDS is required' if intervention_ids.empty?

    interventions = Intervention.where(id: intervention_ids)
    missing = intervention_ids - interventions.map(&:id)
    abort "Interventions not found: #{missing.join(', ')}" if missing.any?

    not_module = interventions.reject(&:module_intervention?)
    abort "Not module interventions: #{not_module.map(&:id).join(', ')}" if not_module.any?

    # A present-but-empty `DRY_RUN` still previews. Only an explicit falsey spelling writes.
    dry_run = ENV.key?('DRY_RUN') && ActiveModel::Type::Boolean.new.cast(ENV.fetch('DRY_RUN', nil)) != false
    actor = 'rake finish_screen:complete_session'

    PaperTrail.request(whodunnit: actor) do
      Audited.audit_class.as_user(actor) do
        ActiveRecord::Base.transaction do
          interventions.each do |intervention|
            finish_screens = Question::Finish.joins(question_group: :session).where(sessions: { intervention_id: intervention.id }).order(:id).to_a
            to_switch = finish_screens.reject { |finish_screen| finish_screen.settings&.dig('show_dashboard_button') == false }
            unless dry_run
              to_switch.each do |finish_screen|
                finish_screen.update!(settings: (finish_screen.settings || {}).merge('show_dashboard_button' => false))
              end
            end

            puts "#{dry_run ? '[DRY RUN] Would switch' : 'Switched'} #{to_switch.size} of #{finish_screens.size} finish screens " \
                 "of intervention #{intervention.id} (#{intervention.name}, #{intervention.status})"
          end
        end
      end
    end
  end
end
