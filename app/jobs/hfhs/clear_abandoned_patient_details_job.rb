# frozen_string_literal: true

# Scanning an Aztec code creates a HfhsPatientDetail carrying real PHI before
# the patient has confirmed anything. A patient who scans and then walks away,
# rescans a different code, or switches to manual entry leaves that draft behind
# with nothing to ever clean it up, so this job expires them.
#
# Scheduled by the `hfhs_clear_abandoned_patient_details` rake task (Heroku
# Scheduler), see lib/tasks/scheduler.rake.
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
