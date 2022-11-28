# frozen_string_literal: true

class Import::Basic::InterventionService
  include ImportOperations
  def self.call(user_id, intervention_hash)
    new(
      user_id,
      intervention_hash.except(:version)
    ).call
  end

  def initialize(user_id, intervention_hash)
    @user = User.find(user_id)
    @logo = intervention_hash.delete(:logo)
    @intervention_hash = intervention_hash
  end

  attr_reader :user, :logo, :intervention_hash
  attr_accessor :intervention

  def call
    sessions = intervention_hash.delete(:sessions)
    accesses = intervention_hash.delete(:intervention_accesses)
    @intervention = Intervention.create!(intervention_hash.merge({ user_id: user.id, google_language: google_language, logo: import_file(logo) }))
    add_logo_description! if logo.present?

    accesses&.each do |intervention_access_hash|
      get_import_service_class(intervention_access_hash, InterventionAccess).call(intervention.id, intervention_access_hash)
    end

    sessions&.each do |session_hash|
      get_import_service_class(session_hash, Session).call(intervention.id, session_hash)
    end

    create_email_and_notification!

    intervention
  end

  private

  def google_language
    @google_language ||= GoogleLanguage.find_by(
      language_name: intervention_hash.delete(:language_name),
      language_code: intervention_hash.delete(:language_code)
    )
  end

  def add_logo_description!
    intervention.logo_blob&.update!(description: logo[:description])
  end

  def create_email_and_notification!
    create_notification!

    return unless user.email_notification

    ImportMailer.result(user, intervention).deliver_now
  end

  def create_notification!
    Notification.create!(user: user, notifiable: intervention, event: :successfully_restored_intervention, data: generate_notification_body)
  end

  def generate_notification_body
    {
      intervention_name: intervention.name,
      intervention_id: intervention.id
    }
  end
end
