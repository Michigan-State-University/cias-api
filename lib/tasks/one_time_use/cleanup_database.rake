# frozen_string_literal: true

namespace :db do
  desc 'Cleanup database before migration to AWS'
  task cleanup: :environment do
    p 'Destroing all user sessions...'
    UserSession.destroy_all
    p 'Finished!'

    p 'Destroing all dashboard sections...'
    DashboardSection.destroy_all
    p 'Finished!'

    p 'Destroing all organizations...'
    Organization.destroy_all
    p 'Finished!'

    p 'Destroing all chart statistics...'
    ChartStatistic.destroy_all
    p 'Finished!'

    p 'Destroing all teams...'
    Team.destroy_all
    p 'Finished!'

    p 'Destroing all invitations...'
    Invitation.destroy_all
    p 'Finished!'

    p 'Destroing all user veryfication codes...'
    UserVerificationCode.destroy_all
    p 'Finished!'

    p 'Destroing all user log requests...'
    UserLogRequest.destroy_all
    p 'Finished!'

    p 'Destroing all audio...'
    Audio.destroy_all
    p 'Finished!'

    p 'Destroing all messages...'
    Message.destroy_all
    p 'Finished!'

    Intervention.find_each do |intervention|
      next if intervention.name.upcase.include? "SAVE"

      p "Destroing intervention with id = #{intervention.id}"
      intervention.sessions.destroy_all
      intervention.destroy
    end

    User.find_each do |user|
      p "Destroing user with id = #{user.id}"
      user.destroy if user.interventions.blank?
    end

    p 'Database is clean!'
    p '=============================================='
    p 'Sessions witch include images:'

    Intervention.all.each do |intervention|
      intervention.sessions.each do |session|
        session.questions.each do |question|
          if question.image.attached?
            p '----------------------------------'
            p "path = '/interventions/#{intervention.id}/sessions/#{session.id}/edit'"
            p "question group = '#{question.question_group.title}'"
            p "question subtitle = '#{question.subtitle}'"
            p "question position = #{question.position}"
            p '----------------------------------'
          end
        end
      end
    end
    p 'end'
  end
end
