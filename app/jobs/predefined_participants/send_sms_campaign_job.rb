# frozen_string_literal: true

# rubocop:disable Rails/SkipsModelValidations
class PredefinedParticipants::SendSmsCampaignJob < ApplicationJob
  queue_as :sms_plans

  RECLAIM_AFTER = 35.minutes
  RESCHEDULE_IN = 15.minutes
  GIVE_UP_AFTER = 24.hours
  TIMEOUT_CODE = 'ApplicationJob::JobTimeoutError'
  RecipientError = Class.new(StandardError)

  def perform(campaign_id)
    @campaign = PredefinedParticipants::SmsCampaign.find_by(id: campaign_id)
    return unless campaign && PredefinedParticipants::SmsCampaign::OPEN_STATUSES.include?(campaign.status)
    return reschedule if campaign.intervention.paused?
    return fail_overdue if overdue?
    return reschedule if postponed?
    return campaign.transition_to('skipped') if skip?
    return unless campaign.transition_to('sending').positive?

    run
  end

  private

  attr_reader :campaign

  def postponed?
    campaign.scheduled_at > Time.current || PredefinedParticipants::SmsCampaign::OPEN_STATUSES.include?(campaign.parent_campaign&.status)
  end

  def skip?
    parent = campaign.parent_campaign
    (parent && !parent.accepted_count.positive?) || !campaign.intervention.published?
  end

  def reschedule
    self.class.set(wait: RESCHEDULE_IN).perform_later(campaign.id)
  end

  def overdue?
    postponed? && campaign.scheduled_at + GIVE_UP_AFTER < Time.current
  end

  def fail_overdue
    return unless campaign.transition_to('failed').positive?

    Rails.logger.warn("[#{self.class.name}] campaign overdue, marked failed: campaign_id=#{campaign.id}")
  end

  def run
    recipients = PredefinedParticipants::SmsRecipientsQuery.call(campaign)
    return if store_recipients_count(recipients) == :empty

    links = V1::PredefinedParticipants::SmsCampaigns::RenderBody.prepare_links(campaign, recipients)
    in_flight = false
    recipients.find_in_batches do |batch|
      sharers = number_sharers(batch)
      batch.each { |pup| in_flight |= (deliver(pup, links, sharers[pup.user.phone.full_number]) == :in_flight) }
    end
    in_flight ? reschedule : campaign.close!
  end

  def number_sharers(batch)
    phones = batch.map { |pup| pup.user.phone }
    Phone.where(prefix: phones.map(&:prefix).uniq, number: phones.map(&:number).uniq).where.not(user_id: nil)
         .each_with_object(Hash.new { |hash, key| hash[key] = [] }) { |phone, sharers| sharers[phone.full_number] << phone.user_id }
  end

  def store_recipients_count(recipients)
    total = recipients.count
    campaign.record_recipients_count(total) if campaign.recipients_count.nil?
    return if total.positive?

    campaign.accepted_count.positive? ? campaign.close! : campaign.transition_to('skipped')
    :empty
  end

  def deliver(pup, links, recipient_user_ids)
    delivery = claim(pup, links)
    return delivery if delivery.is_a?(Symbol)

    send_to(pup, delivery, recipient_user_ids)
    :done
  end

  def claim(pup, links)
    body = V1::PredefinedParticipants::SmsCampaigns::RenderBody.call(campaign, pup, links)
    PredefinedParticipants::SmsDelivery.claim(campaign_id: campaign.id, predefined_user_parameter_id: pup.id, body: body) || take_over(pup, body)
  rescue ApplicationJob::JobTimeoutError
    raise
  rescue StandardError => e
    report(e)
    :error
  end

  def take_over(pup, body)
    rows = PredefinedParticipants::SmsDelivery.where(campaign_id: campaign.id, predefined_user_parameter_id: pup.id)
    handed_off = rows.where(status: 'pending').where.not(message_id: nil).pick(:id, :message_id)
    return reconcile(pup, handed_off) if handed_off

    won = rows.where(status: 'pending', message_id: nil).where(updated_at: ...RECLAIM_AFTER.ago)
              .update_all(updated_at: Time.current, body: body).positive?
    return rows.take if won

    rows.pick(:status) == 'pending' ? :in_flight : :done
  end

  def reconcile(pup, (delivery_id, message_id))
    mark_sent(pup, delivery_id, message_id)
    :done
  end

  def send_to(pup, delivery, recipient_user_ids)
    result = V1::PredefinedParticipants::DeliverSms.call(pup.user.phone.full_number, delivery.body, recipient_user_ids: recipient_user_ids)
    message = result.message
    record_handoff(delivery.id, message, result)
    code = provider_error_code(result)
    code ? mark_failed(delivery.id, code, message.id) : mark_sent(pup, delivery.id, message.id)
  rescue ApplicationJob::JobTimeoutError
    raise
  rescue StandardError => e
    report(e)
    mark_failed(delivery.id, e.class.name.presence || 'StandardError', message&.id)
  end

  def record_handoff(delivery_id, message, result)
    rejected = result.error_code.present? && result.error_code != TIMEOUT_CODE
    return if message.nil? || rejected

    PredefinedParticipants::SmsDelivery.where(id: delivery_id, status: 'pending')
                                       .update_all(message_id: message.id, updated_at: Time.current)
  end

  def provider_error_code(result)
    code = result.error_code
    raise ApplicationJob::JobTimeoutError, 'execution expired' if code == TIMEOUT_CODE

    code
  end

  def mark_sent(pup, delivery_id, message_id)
    now = Time.current
    ApplicationRecord.transaction do
      sent = PredefinedParticipants::SmsDelivery.where(id: delivery_id, status: 'pending')
                                                .update_all(status: 'sent', message_id: message_id, sent_at: now, updated_at: now)
      raise ActiveRecord::Rollback unless sent.positive?

      PredefinedParticipants::SmsCampaign.update_counters(campaign.id, accepted_count: 1)
      stamp(pup, now)
    end
  end

  def stamp(pup, now)
    column = campaign.invitation? ? :sms_invitation_sent_at : :last_reminder_sent_at
    PredefinedUserParameter.where(id: pup.id).update_all(column => now, updated_at: now)
  end

  def mark_failed(delivery_id, error_code, message_id = nil)
    now = Time.current
    ApplicationRecord.transaction do
      failed = PredefinedParticipants::SmsDelivery.where(id: delivery_id, status: 'pending')
                                                  .update_all(status: 'failed', error_code: error_code,
                                                              message_id: message_id, updated_at: now)
      PredefinedParticipants::SmsCampaign.update_counters(campaign.id, failed_count: 1) if failed.positive?
    end
  rescue ApplicationJob::JobTimeoutError
    raise
  rescue StandardError => e
    report(e)
  end

  def report(error)
    Rails.logger.warn("[#{self.class.name}] recipient failed: campaign_id=#{campaign.id} error=#{error.class}")
    V1::PredefinedParticipants::ReportSmsError.call(RecipientError, error.class.name, extra: { campaign_id: campaign.id }, backtrace: error.backtrace)
  end
end
# rubocop:enable Rails/SkipsModelValidations
