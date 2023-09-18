# frozen_string_literal: true

class V1::Intervention::CreateInvitation
  def self.call(intervention, create_invitations_params)
    new(intervention, create_invitations_params).call
  end

  def initialize(intervention, create_invitations_params)
    @intervention = intervention
    @create_invitations_params = create_invitations_params
  end

  def call
    create_invitations_params.each do |invitation_params|
      create_invitations!(invitation_params)
    end
  end

  attr_reader :intervention, :create_invitations_params

  private

  def create_invitations!(invitation_params)

    object = fetch_object(invitation_params)
    if wrong_type_of_invitation_for_object?(invitation_params, object)
      raise ActiveModel::ForbiddenAttributesError, I18n.t('interventions.invitations.wrong_intervention_type')
    end

    object.invite_by_email(invitation_params[:emails], invitation_params[:health_clinic_id])
  end

  def fetch_object(invitation_params)
    invitation_params['target_type'].classify.demodulize.safe_constantize.find(invitation_params['target_id'])
  end

  def wrong_type_of_invitation_for_object?(params, object)
    (params['target_type'].eql?('intervention') && object.type.eql?('Intervention')) || (params['target_type'].eql?('session') && object.type != 'Intervention')
  end
end
