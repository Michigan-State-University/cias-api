# frozen_string_literal: true

module ActiveStorage::DirectUploadDenied
  def self.prepended(base)
    # Callback, not an overridden `create`: CSRF runs first and would answer 422 instead.
    base.prepend_before_action { head :not_found }
  end
end
