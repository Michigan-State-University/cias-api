# frozen_string_literal: true

class InterventionChannel < ApplicationCable::Channel
  include CableExceptionHandler
  include MessageHandler

  def subscribed
    reject unless Intervention.find(params[:id]).in?(accessible_interventions)

    stream_from intervention_channel_id
    ensure_confirmation_sent
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    purge_editor_and_create_notifications!(Intervention.find(params[:id])) if intervention.current_editor_id == current_user.id
    stop_all_streams
  end

  def on_editing_started
    intervention = Intervention.find(params[:id])

    raise_exception if intervention.current_editor_id.present? || intervention.published?
    raise_exception unless intervention.in?(accessible_interventions)

    assign_current_editor!(intervention)

    ActionCable.server.broadcast(
      intervention_channel_id, generic_message(
                                 { current_editor: { id: current_user.id, email: current_user.email, first_name: current_user.first_name,
                                                     last_name: current_user.last_name } },
                                 'editing_started'
                               )
    )
  end

  def on_force_editing_started
    intervention = Intervention.find(params[:id])

    raise_exception if intervention.user_id != current_user.id || intervention.published?
    raise_exception unless intervention.in?(accessible_interventions)

    assign_current_editor!(intervention)

    ActionCable.server.broadcast(
      intervention_channel_id, generic_message(
                                 { current_editor: { id: current_user.id, email: current_user.email, first_name: current_user.first_name,
                                                     last_name: current_user.last_name } },
                                 'force_editing_started'
                               )
    )
  end

  def on_editing_stopped
    intervention = Intervention.find(params[:id])

    raise_exception if intervention.current_editor_id != current_user.id || intervention.published?
    raise_exception unless intervention.in?(accessible_interventions)

    purge_editor_and_create_notifications!(intervention)

    ActionCable.server.broadcast(
      intervention_channel_id, generic_message(
                                 {},
                                 'editing_stopped'
                               )
    )
  end

  private

  def intervention_channel_id
    "intervention_channel_#{params[:id]}"
  end

  def accessible_interventions
    @accessible_interventions = Intervention.accessible_by(current_user.ability, :update)
  end

  def purge_editor_and_create_notifications!(intervention)
    intervention.update!(current_editor: nil)
    notifications!(intervention, :stop_editing_intervention)
  end

  def notifications!(intervention, type)
    listing_users(intervention).each do |user|
      Notification.create!(user: user, notifiable: intervention, event: type,
                           data: generate_notification_body(intervention, current_user))
    end
  end

  def listing_users(intervention)
    User.left_joins(:collaborations, :interventions).where.not(id: current_user.id).and(
      User.left_joins(:collaborations, :interventions).where(interventions: { user_id: intervention.user_id })
          .or(User.left_joins(:collaborations, :interventions).where(collaborations: { intervention_id: intervention.id }))
    )
  end

  def generate_notification_body(intervention, user)
    {
      intervention_name: intervention.name,
      intervention_id: intervention.id,
      user_id: user.id,
      first_name: user.first_name,
      last_name: user.last_name,
      avatar_url: user.avatar.attached? ? polymorphic_url(object.avatar) : ''
    }
  end

  def assign_current_editor!(intervention)
    intervention.update(current_editor: current_user)
    notifications!(intervention, :start_editing_intervention)
  end

  def raise_exception
    raise Cable::OperationalInvalidException.new(I18n.t('channels.collaboration.intervention.forbidden_action'), intervention_channel_id)
  end
end
