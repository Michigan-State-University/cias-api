# frozen_string_literal: true

class HenryFord::MultiplePatientsFoundError < StandardError
  def initialize(msg = I18n.t('henry_ford.error.patient.multiple_found'))
    super
  end
end
