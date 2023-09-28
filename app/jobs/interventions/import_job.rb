# frozen_string_literal: true

class Interventions::ImportJob < ApplicationJob
  include ImportOperations

  sidekiq_options retry: false

  def perform(user_id, intervention_hash)
    ActiveRecord::Base.transaction do
      get_import_service_class(intervention_hash, Intervention).call(user_id, intervention_hash)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::SubclassNotFound, ActiveModel::UnknownAttributeError
      create_email_and_notification!(user_id, locale: intervention_hash[:language_code])
    end
  end

  private

  def create_email_and_notification!(user_id, locale)
    user = User.find(user_id)
    create_notification!(user)

    return unless user.email_notification

    ImportMailer.with(locale: locale).unsuccessful(user).deliver_now
  end

  def create_notification!(user)
    Notification.create!(user: user, notifiable: user, event: :unsuccessful_intervention_import, data: notification_body)
  end

  def notification_body
    {
      message: I18n.t('import_mailer.unsuccessful.notification')
    }
  end
end
