# frozen_string_literal: true

class MultipleCharacters::ChangeNarratorJob < ApplicationJob
  queue_as :default

  def perform(user, model, object_id, new_character, new_animations)
    "V1::MultipleCharacters::#{model.pluralize}::ChangeService".safe_constantize.
      call(object_id, new_character, new_animations)

    MultipleNarratorsMailer.successfully_changed(user, model.safe_constantize.find(object_id)).deliver_now
  end
end
