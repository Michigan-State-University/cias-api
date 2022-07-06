# frozen_string_literal: true

class V1::LiveChat::InviteNavigators
  def self.call(emails, intervention)
    new(emails, intervention).call
  end

  def initialize(emails, intervention)
    @emails = emails
    @intervention = intervention
  end

  def call
    users_exists = User.where(email: emails)
    check_roles_of_existing_users(users_exists)

    ActiveRecord::Base.transaction do
      add_navigator_role(users_exists)
      invite_new_users_to_system(emails - users_exists.map(&:email))

      User.where(email: emails).find_each do |user|
        LiveChat::Interventions::NavigatorInvitations.create(email: user.email, intervention: @intervention)
      end
    end

    Navigators::InvitationJob.perform_later(emails, intervention.id)
  end

  attr_reader :emails, :intervention
  attr_accessor :user, :users_exists

  private

  def check_roles_of_existing_users(users)
    users.each do |user|
      raise ActiveRecord::RecordInvalid, I18n.t('activerecord.errors.models.live_chat.navigator.not_researcher') unless user.researcher?
    end
  end

  def add_navigator_role(users)
    users.each do |user|
      user.update!(roles: (user.roles << 'navigator')) unless user.navigator?
    end
  end

  def invite_new_users_to_system(emails)
    emails.each do |email|
      User.invite!(email: email, roles: ['navigator'])
    end
  end
end
