# frozen_string_literal: true

class V1::Export::InterventionSerializer < ActiveModel::Serializer
  include FileHelper

  attributes :quick_exit, :type, :shared_to, :additional_text, :original_text, :current_narrator, :skip_warning_screen

  has_many :sessions, serializer: V1::Export::SessionSerializer do
    object.sessions.where(type: %w[Session::Classic Session::Sms])
  end
  has_many :intervention_accesses, serializer: V1::Export::InterventionAccessSerializer

  attribute :name do
    "Imported #{object.name}"
  end

  attribute :language_name do
    object.google_language.language_name
  end

  attribute :language_code do
    object.google_language.language_code
  end

  attribute :logo do
    export_file(object.logo)
  end

  attribute :version do
    Intervention::CURRENT_VERSION
  end
end
