# frozen_string_literal: true

module TeamCollaboratorsHelper
  extend ActiveSupport::Concern

  included do
    attribute :has_collaborators do |object|
      object.collaborators.any?
    end

    attribute :is_current_user_collaborator do |object, params|
      object.collaborators.where(user_id: params[:current_user_id]).any?
    end

    attribute :current_user_collaborator_data do |object, params|
      collaborator = object.collaborators.find_by(user_id: params[:current_user_id])
      if collaborator.present?
        {
          id: collaborator.id,
          view: collaborator.view,
          edit: collaborator.edit,
          data_access: collaborator.data_access
        }
      end
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
