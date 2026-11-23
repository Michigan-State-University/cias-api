# frozen_string_literal: true

# Removes unconfirmed scan drafts; each draft enqueues it (HandleBarCodeService).
class Hfhs::ClearAbandonedPatientDetailsJob < ApplicationJob
  queue_as :hfhs

  RETENTION_PERIOD = 1.day

  def perform
    abandoned_patient_details.find_each(&:destroy!)
  end

  private

  def abandoned_patient_details
    HfhsPatientDetail.where(pending: true)
                     .where(updated_at: ...RETENTION_PERIOD.ago)
                     .where.missing(:users)
  end
end
