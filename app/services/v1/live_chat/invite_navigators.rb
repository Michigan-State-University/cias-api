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
    user_emails_to_invite = filter_invited_navigators(emails)
    users_exists = User.where(email: user_emails_to_invite)
    check_roles_of_existing_users(users_exists)

    invitations = []
    ActiveRecord::Base.transaction do
      add_navigator_role(users_exists)
      invite_new_users_to_system(emails - users_exists.map(&:email))

      User.where(email: user_emails_to_invite).find_each do |user|
        invitations << LiveChat::Interventions::NavigatorInvitation.create(email: user.email, intervention: @intervention)
      end
    end

    Navigators::InvitationJob.perform_later(user_emails_to_invite, intervention.id)
    invitations
  end

  attr_reader :emails, :intervention
  attr_accessor :user, :users_exists

  private

  def check_roles_of_existing_users(users)
    users.each do |user|
      raise CanCan::AccessDenied, I18n.t('activerecord.errors.models.live_chat.navigator.not_researcher') unless user.researcher? || user.navigator?
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

  def filter_invited_navigators(emails)
    emails.select do |email|
      !intervention.live_chat_navigator_invitations.not_accepted.exists?(email: email) && !intervention.navigators.exists?(email: email)
    end
  end
end
