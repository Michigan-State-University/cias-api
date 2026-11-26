# frozen_string_literal: true

class Ehr::PatientIdentifierMissingError < StandardError
  def initialize(msg = I18n.t('ehr.error.patient.identifier_missing'))
    super
  end
end
