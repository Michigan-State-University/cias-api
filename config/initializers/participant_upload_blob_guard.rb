# frozen_string_literal: true

Rails.application.config.to_prepare do
  [
    ActiveStorage::Blobs::RedirectController,
    ActiveStorage::Blobs::ProxyController,
    ActiveStorage::Representations::RedirectController,
    ActiveStorage::Representations::ProxyController
  ].each { |controller| controller.prepend(ActiveStorage::ParticipantUploadGuard) }

  ActiveStorage::DirectUploadsController.prepend(ActiveStorage::DirectUploadDenied)
end
