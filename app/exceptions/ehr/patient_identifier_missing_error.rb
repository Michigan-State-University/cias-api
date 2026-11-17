# frozen_string_literal: true

class Ehr::PatientIdentifierMissingError < StandardError
  def initialize(msg = I18n.t('henry_ford.error.patient.identifier_missing'))
    super
  end
end
