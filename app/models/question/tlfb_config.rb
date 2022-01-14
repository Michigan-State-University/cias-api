# frozen_string_literal: true

class Question::TlfbConfig < Question::Tlfb
  attribute :narrator, :json, default: {
    'settings' => {
      'voice' => false,
      'animation' => false
    },
    'blocks' => []
  }

  protected

  def tlfb_body_validation
    errors[:base].add(I18n.t('activerecord.errors.models.question.tlfb.config.narrator_enabled')) if narrator['settings']['voice'] || narrator['settings']['animation'] # rubocop:disable Layout/LineLength
  end
end
