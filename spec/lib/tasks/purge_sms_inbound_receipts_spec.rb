# frozen_string_literal: true

RSpec.describe 'purge_sms_inbound_receipts' do
  include ActiveSupport::Testing::TimeHelpers

  let(:task_name) { 'purge_sms_inbound_receipts' }
  let(:now) { Time.utc(2026, 11, 2, 12, 0, 0) }

  before do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    travel_to now
  end

  def invoke
    task = Rake::Task[task_name]
    task.reenable
    task.invoke
  end

  it 'deletes receipts past the retention window and keeps recent ones' do
    stale = SmsInboundReceipt.create!(message_sid: 'SM_old', created_at: SmsInboundReceipt::RETENTION.ago - 1.day)
    fresh = SmsInboundReceipt.create!(message_sid: 'SM_new', created_at: 1.day.ago)

    invoke

    expect(SmsInboundReceipt.exists?(stale.id)).to be(false)
    expect(SmsInboundReceipt.exists?(fresh.id)).to be(true)
  end
end
