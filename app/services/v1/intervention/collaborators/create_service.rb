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
    invite_non_existing_users(non_existing_users_emails, true, [:researcher]) # maybe second parameter should be false

    ActiveRecord::Base.transaction do
      parameters = User.where(email: emails).limit_to_roles(:researcher).map { |user| { user: user, intervention: intervention } }
      Collaborator.create!(parameters)
    end
  end

  attr_reader :emails
  attr_accessor :intervention
end
