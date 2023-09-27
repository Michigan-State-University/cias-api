# frozen_string_literal: true

class MultipleCharacters::ChangeNarratorJob < ApplicationJob
  queue_as :default

  def perform(user, model, object_id, new_character, new_animations = {})
    "V1::MultipleCharacters::#{model.pluralize}::ChangeService".safe_constantize.
      call(object_id, new_character, new_animations)

    @object = model.safe_constantize.find(object_id)
    MultipleNarratorsMailer.with(locale: object.language_code).successfully_changed(user.email, object).deliver_now
    Notification.create!(user: user, notifiable: object, event: :new_narrator_was_set, data: generate_notification_body)
  end

  attr_accessor :object

  private

  def generate_notification_body
    {
      name: object.name,
      new_narrator: object.current_narrator
    }
  end
end
