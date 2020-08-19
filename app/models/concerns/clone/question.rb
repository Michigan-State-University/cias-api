# frozen_string_literal: true

class Clone::Question < Clone::Base
  def execute
    attach_image
    outcome.variable_clone_prefix
    outcome.formula['payload'] = ''
    outcome.save!
    outcome
  end

  private

  def attach_image
    outcome.image.attach(source.image.blob) if source.image.attachment
  end
end
