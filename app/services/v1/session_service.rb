# frozen_string_literal: true

class V1::SessionService
  def initialize(user, intervention_id)
    @user = user
    @intervention_id = intervention_id
    @intervention = Intervention.includes(:sessions).accessible_by(user.ability).find(intervention_id)
  end

  attr_reader :user, :intervention_id
  attr_accessor :intervention

  def sessions
    intervention.sessions.order(:position)
  end

  def session_load(id)
    sessions.find(id)
  end

  def create(session_params)
    session = sessions.new(session_params)
    session.position = sessions.last&.position.to_i + 1
    session.save!
    session
  end

  def update(session_id, session_params)
    session = session_load(session_id)
    session.assign_attributes(session_params)
    session.integral_update
    session
  end

  def destroy(session_id)
    session_load(session_id).destroy! if intervention.draft?
  end

  def duplicate(session_id, new_intervention_id)
    new_intervention = Intervention.accessible_by(user.ability).find(new_intervention_id)
    old_session = session_load(session_id)
    Clone::Session.new(old_session,
                       intervention_id: new_intervention.id,
                       clean_formulas: true,
                       position: new_intervention.sessions.last&.position.to_i + 1).execute
  end


  private

  def clear_branching(object, session_id)
    object.formula['patterns'].each do |pattern|
      pattern['target'].each do |target|
        if target['id'].eql?(session_id)
          target['id'] = ''
          object.save!
        end
      end
    end
  end
end
