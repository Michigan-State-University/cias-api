# frozen_string_literal: true

class MultipleCharacters::ChangeNarratorJob < ApplicationJob
  queue_as :default

  def perform(model, object_id, new_character, new_animations)
    "V1::MultipleCharacters::#{model.pluralize}::ChangeService".safe_constantize.
      call(object_id, new_character, new_animations)
  end
end
