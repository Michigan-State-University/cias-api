# frozen_string_literal: true

class V1::ParticipantUploadSerializer < V1Serializer
  attributes :question_id, :user_session_id, :original_filename, :description,
             :content_type_detected, :byte_size, :scan_status

  attribute :inline_preview do |object|
    object.servable? && object.served_inline?
  end

  attribute :deletion_reason do |object|
    object.deletion_reason if object.removed_by_scanner?
  end

  attribute :moderation_status, if: proc { |_object, params| params[:show_moderation] }

  attribute :moderation_labels, if: proc { |_object, params| params[:show_moderation] } do |object|
    object.moderation_labels || []
  end

  attribute :moderation_skip_reason, if: proc { |_object, params| params[:show_moderation] } do |object|
    object.moderation_skip_reason if object.moderation_status == 'skipped'
  end

  attribute :moderation_model_version, if: proc { |_object, params| params[:show_moderation] }
end
