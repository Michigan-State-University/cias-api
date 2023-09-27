# frozen_string_literal: true

class V1::Intervention::Collaborators::CreateService
  include InvitationInterface

  def self.call(intervention, emails)
    new(intervention, emails).call
  end

  def initialize(intervention, emails)
    @emails = emails.map!(&:downcase)
    @intervention = intervention
  end

  def call
    _existing_users_emails, non_existing_users_emails = split_emails_exist(emails)
    invite_non_existing_users(non_existing_users_emails, true, [:researcher])

    ActiveRecord::Base.transaction do
      parameters = new_collaborators.map { |user| { user: user, intervention: intervention } }
      @created_collaborators = Collaborator.create!(parameters)
    end

    send_emails_and_notifications!(non_existing_users_emails)

    @created_collaborators
  end

  attr_reader :emails, :created_collaborators
  attr_accessor :intervention

  private

  def send_emails_and_notifications!(new_user_emails)
    new_collaborators.each do |user|
      InterventionMailer::CollaboratorsMailer.with(locale: intervention.language_code)
                                             .invitation_user(user, intervention, user.email.in?(new_user_emails)).deliver_now
      Notification.create!(user: user, notifiable: intervention, event: :new_collaborator_added, data: generate_notification_body)
    end
  end

  def generate_notification_body
    {
      intervention_name: intervention.name,
      intervention_id: intervention.id
    }
  end

  def new_collaborators
    @new_collaborators ||= User.where(email: emails).limit_to_roles(%i[researcher admin])
  end
end
