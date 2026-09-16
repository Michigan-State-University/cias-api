# frozen_string_literal: true

RSpec.describe PredefinedParticipants::BulkImportJob, type: :job do
  subject(:perform) { described_class.new.perform(payload_id) }

  let!(:researcher) { create(:user, :confirmed, :researcher) }
  let!(:intervention) { create(:intervention, user_id: researcher.id) }
  let(:payload_value) do
    [{ 'attributes' => { 'first_name' => 'A', 'last_name' => 'B', 'email' => 'p@example.test' },
       'variable_answers' => {} }]
  end
  let!(:payload_record) do
    BulkImportPayload.create!(researcher: researcher, intervention: intervention, payload: payload_value)
  end
  let(:payload_id) { payload_record.id }
  let(:service_result) do
    { total: 1, participants_created: 1, ra_completed: 0, ra_partial: 0, failed: 0 }
  end

  before do
    # Stub the service so we can assert what the job does around it without
    # re-running the full DB-writing service under a job context.
    allow(V1::Intervention::PredefinedParticipants::BulkImportService).to receive(:call).and_return(service_result)
  end

  describe 'happy path' do
    it 'calls the service with decrypted payload' do
      perform
      expect(V1::Intervention::PredefinedParticipants::BulkImportService)
        .to have_received(:call).with(researcher, intervention, payload_value)
    end

    it 'sends the result email' do
      expect { perform }.to have_enqueued_mail(BulkImportMailer, :bulk_import_result)
        .or change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it 'destroys the payload row' do
      expect { perform }.to change(BulkImportPayload, :count).by(-1)
    end
  end

  describe 'service raises StandardError' do
    before do
      allow(V1::Intervention::PredefinedParticipants::BulkImportService)
        .to receive(:call).and_raise(StandardError, 'boom')
    end

    it 'captures to Sentry and sends the error email (not the result email)' do
      expect(Sentry).to receive(:capture_exception).with(instance_of(StandardError))
      expect(BulkImportMailer).to receive(:bulk_import_error).with(researcher, intervention).and_call_original
      expect(BulkImportMailer).not_to receive(:bulk_import_result)
      perform
    end

    it 'still destroys the payload row' do
      allow(Sentry).to receive(:capture_exception)
      expect { perform }.to change(BulkImportPayload, :count).by(-1)
    end
  end

  describe 'success-email mailer failure must NOT trigger the error email' do
    it 'captures the mailer failure to Sentry but does not call bulk_import_error' do
      # Simulate the success mailer raising on deliver_now.
      failing_mailer = instance_double(ActionMailer::MessageDelivery)
      allow(failing_mailer).to receive(:deliver_now).and_raise(StandardError, 'smtp down')
      allow(BulkImportMailer).to receive(:bulk_import_result).and_return(failing_mailer)

      expect(BulkImportMailer).not_to receive(:bulk_import_error)
      expect(Sentry).to receive(:capture_exception).with(instance_of(StandardError))

      perform
    end
  end

  describe 'retry after destroy is idempotent' do
    it 'second call returns cleanly without re-running the service' do
      described_class.new.perform(payload_id) # first call destroys the payload

      expect(V1::Intervention::PredefinedParticipants::BulkImportService).not_to receive(:call)
      expect(BulkImportMailer).not_to receive(:bulk_import_result)
      expect(BulkImportMailer).not_to receive(:bulk_import_error)

      described_class.new.perform(payload_id)
    end
  end

  describe 'missing payload (never existed)' do
    let(:payload_id) { SecureRandom.uuid }

    it 'returns cleanly without calling service or mailer' do
      expect(V1::Intervention::PredefinedParticipants::BulkImportService).not_to receive(:call)
      expect(BulkImportMailer).not_to receive(:bulk_import_result)
      expect(BulkImportMailer).not_to receive(:bulk_import_error)
      perform
    end
  end

  describe 'researcher.email_notification = false' do
    before { researcher.update!(email_notification: false) }

    it 'does not send an email on the happy path' do
      expect(BulkImportMailer).not_to receive(:bulk_import_result)
      perform
    end

    it 'does not send an email on the error path either' do
      allow(V1::Intervention::PredefinedParticipants::BulkImportService)
        .to receive(:call).and_raise(StandardError, 'boom')
      allow(Sentry).to receive(:capture_exception)
      expect(BulkImportMailer).not_to receive(:bulk_import_error)
      perform
    end
  end

  describe 'observability (logging)' do
    it 'logs Starting with researcher + intervention IDs and row count' do
      allow(Rails.logger).to receive(:info)
      perform
      expect(Rails.logger).to have_received(:info)
        .with(match(/Starting.*researcher_id=#{researcher.id}.*intervention_id=#{intervention.id}.*rows=1/))
    end

    it 'logs Completed with counters from the service result' do
      allow(Rails.logger).to receive(:info)
      perform
      expect(Rails.logger).to have_received(:info)
        .with(match(/Completed.*participants_created=1.*ra_completed=0.*ra_partial=0.*failed=0/))
    end

    it 'logs Service raised (warn) with exception CLASS, not message' do
      allow(V1::Intervention::PredefinedParticipants::BulkImportService)
        .to receive(:call).and_raise(StandardError, 'leak_canary: p@example.test')
      allow(Sentry).to receive(:capture_exception)
      allow(Rails.logger).to receive(:warn)

      perform

      expect(Rails.logger).to have_received(:warn)
        .with(match(/Service raised.*error=StandardError/))
      expect(Rails.logger).not_to have_received(:warn).with(match(/leak_canary/))
    end

    it 'logs Email skipped when researcher.email_notification is false' do
      researcher.update!(email_notification: false)
      allow(Rails.logger).to receive(:info)

      perform

      expect(Rails.logger).to have_received(:info)
        .with(match(/Email skipped.*email_notification=false.*researcher_id=#{researcher.id}/))
    end

    it 'HIPAA: no log line contains researcher email or participant CSV PII' do
      captured = []
      %i[info warn error].each do |level|
        allow(Rails.logger).to receive(level) { |msg| captured << msg.to_s }
      end

      perform

      all_logs = captured.join("\n")
      expect(all_logs).not_to include(researcher.email)
      expect(all_logs).not_to include('p@example.test') # participant email from payload_value
    end
  end

  describe 'HIPAA — perform_later args carry only the UUID' do
    it 'enqueues with a single UUID string, no PII' do
      expect do
        described_class.perform_later(payload_id)
      end.to have_enqueued_job(described_class).with(payload_id)

      # Also verify the serialised arg is exactly a UUID — no hash, no array.
      job = ActiveJob::Base.queue_adapter.enqueued_jobs.last
      expect(job[:args]).to eq([payload_id])
      expect(job[:args].first).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
    end
  end
end
