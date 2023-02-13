# frozen_string_literal: true

module UserHelper
  extend ActiveSupport::Concern

  class_methods do
    def map_navigator_data(navigator)
      {
        id: navigator.id,
        first_name: navigator.first_name,
        last_name: navigator.last_name,
        email: navigator.email,
        avatar_url: navigator.avatar.attached? ? polymorphic_url(navigator.avatar) : nil
      }
    end

    def map_invitation(invitation)
      {
        id: invitation.id,
        email: invitation.email,
        type: 'navigator_invitation'
      }
    end
  end
end
