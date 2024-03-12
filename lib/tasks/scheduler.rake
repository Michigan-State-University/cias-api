# frozen_string_literal: true

desc 'This tasks are called by the Heroku scheduler add-on'
task interventions_schedule: :environment do
  start_end_at = Date.current.all_day
  interventions = Intervention.joins(:user_interventions).where(schedule_at: start_end_at)
                              .or(Intervention.joins(:user_interventions).where(user_interventions: { schedule_at: start_end_at }))

  users = User.where(id: interventions.users)
  interventions.each do |intervention|
    intervention.user_interventions.each do |user_intervention|
      InvitationMailer.with(locale: intervention.language_code)
                      .added_user_to_intervention(users.find(user_intervention.user_id).email, intervention).deliver_now
    end
  end
end
