# frozen_string_literal: true

class V1::InvitationSerializer < V1Serializer
  attributes :email
  attribute :health_clinic_id, if: proc { |_record, params|
    params.nil? || params[:only_email].nil? || params[:only_email] == false
  }
end
