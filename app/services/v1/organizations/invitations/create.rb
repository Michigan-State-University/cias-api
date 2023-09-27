# frozen_string_literal: true

class V1::Organizations::Invitations::Create
  def self.call(organizable, user)
    new(organizable, user).call
  end

  def initialize(organizable, user)
    @organizable = organizable
    @user = user
  end

  def call
    return if invitation_already_exists?
    return unless user.confirmed?

    invitation = "#{organizable.class.name}Invitation".safe_constantize.create!(
      user: user,
      "#{organizable.class.table_name.singularize}": organizable
    )

    OrganizableMailer.invite_user(
      invitation_token: invitation.invitation_token,
      email: user.email,
      organizable: organizable,
      organizable_type: organizable.class.name.titlecase
    ).deliver_later # TODO: locale
  end

  private

  attr_reader :organizable, :user

  def invitation_already_exists?
    "#{organizable.class.name}Invitation".safe_constantize.not_accepted.exists?(user_id: user.id,
                                                                                "#{organizable.class.table_name.singularize}_id": organizable.id)
  end
end
