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
    created_users = []
    ActiveRecord::Base.transaction do
      params.each do |participant_params|
        user = V1::Intervention::PredefinedParticipants::CreateService.new(intervention, participant_params).call
        created_users << user
      end
    end
    created_users
  end

  private

  attr_reader :params, :intervention
end
