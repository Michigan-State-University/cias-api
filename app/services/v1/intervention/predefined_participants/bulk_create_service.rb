# frozen_string_literal: true

class V1::Intervention::PredefinedParticipants::BulkCreateService
  def initialize(intervention, params)
    @intervention = intervention
    @params = params[:participants]
  end

  def self.call(intervention, params)
    new(intervention, params).call
  end

  def call
    ActiveRecord::Base.transaction do
      params.map do |participant_params|
        V1::Intervention::PredefinedParticipants::CreateService.new(intervention, participant_params).call
      end
    end
  end

  private

  attr_reader :params, :intervention
end
