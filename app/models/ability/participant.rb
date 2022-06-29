# frozen_string_literal: true

class Ability::Participant < Ability::Base
  include Ability::Generic::FillInterventionAccess

  def definition
    super
    participant if role?(class_name)
  end

  private

  def participant
    enable_fill_in_access(user.id, Intervention.available_for_participant(user.email))
    can %i[read get_protected_attachment], GeneratedReport, participant_id: user.id, report_for: 'participant'
    can %i[index create], LiveChat::Conversation
  end
end
