# frozen_string_literal: true

class V1::Intervention::Collaborators::DestroyService
  include InvitationInterface

  def self.call(collaborator)
    new(collaborator).call
  end

  def initialize(collaborator)
    @collaborator = collaborator
    @user = collaborator.user
    @intervention = collaborator.intervention
  end

  def call
    ActiveRecord::Base.transaction do
      collaborator.destroy
      notification!
    end
  end

  attr_accessor :collaborator
  attr_reader :user, :intervention

  private

  def notification!
    Notification.create!(user: user, notifiable: intervention, event: :collaborator_removed, data: generate_notification_body)
  end

  def generate_notification_body
    {
      intervention_name: intervention.name,
      intervention_id: intervention.id
    }
  end
end
