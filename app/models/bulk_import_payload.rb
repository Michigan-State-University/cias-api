# frozen_string_literal: true

# Short-lived Lockbox-encrypted holder for PDPs bulk-import payload.
class BulkImportPayload < ApplicationRecord
  belongs_to :researcher, class_name: 'User'
  belongs_to :intervention

  has_encrypted :payload, type: :json

  # Exclude BOTH names - Lockbox audits the virtual attr + ciphertext separately.
  audited except: %i[payload payload_ciphertext]
end
