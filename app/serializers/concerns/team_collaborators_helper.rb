# frozen_string_literal: true

module TeamCollaboratorsHelper
  extend ActiveSupport::Concern

  included do
    attribute :has_collaborators do |object|
      object.collaborators.any?
    end

    attribute :current_editor do |object|
      if object.current_editor_id.present?
        {
          id: object.current_editor_id,
          first_name: object.current_editor.first_name,
          last_name: object.current_editor.last_name,
          email: object.current_editor.email
        }
      end
    end
  end
end
