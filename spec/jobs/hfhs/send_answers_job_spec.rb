# frozen_string_literal: true

RSpec.describe Hfhs::SendAnswersJob, type: :job do
  subject(:perform_job) { described_class.perform_now(user_session.id) }

  include_context 'with HL7 settings configured'

  let_it_be(:researcher) { create(:user, :confirmed, :researcher) }
  let_it_be(:intervention) { create(:intervention, user: researcher, status: :published, shared_to: :anyone) }
  let_it_be(:session) do
    RSpec::Mocks.with_temporary_scope do
      allow_any_instance_of(Question).to receive(:execute_narrator).and_return(true)
      create(:session, intervention: intervention)
    end
  end

  let(:api) { instance_double(Api::Hl7Receiver, send_answers: true, send_reports: true) }
  let(:user_session) { create(:user_session, user: user, session: session) }

  before { allow(Api::Hl7Receiver).to receive(:new).and_return(api) }

  context 'with an ordinary participant' do
    let(:user) { create(:user, :confirmed, :participant, :with_hfhs_patient_detail) }

    it 'sends the answers and the reports' do
      perform_job

      expect(api).to have_received(:send_answers).with(user_session.id)
      expect(api).to have_received(:send_reports).with(user_session.id)
    end
  end

  context 'with a participant who never verified their HFHS details' do
    let(:user) { create(:user, :confirmed, :participant) }

    it 'transmits nothing to HFHS' do
      perform_job

      expect(api).not_to have_received(:send_answers)
      expect(api).not_to have_received(:send_reports)
    end

    it 'records why it withheld the transmission' do
      allow(Rails.logger).to receive(:warn)

      perform_job

      expect(Rails.logger).to have_received(:warn).with(
        a_string_including('skipped HL7 transmission for a patient without verified EHR patient details', "user_session_id=#{user_session.id}")
      )
    end
  end

  context 'with a test participant' do
    let(:user) do
      create(:user, :confirmed, :guest).tap do |guest|
        guest.update!(test_run: true, test_run_intervention_id: intervention.id)
      end
    end

    it 'transmits nothing to HFHS' do
      perform_job

      expect(api).not_to have_received(:send_answers)
      expect(api).not_to have_received(:send_reports)
    end

    it 'records why it withheld the transmission' do
      allow(Rails.logger).to receive(:warn)

      perform_job

      expect(Rails.logger).to have_received(:warn).with(
        a_string_including('skipped HL7 transmission for a test run', "user_id=#{user.id}")
      )
    end
  end

  it 'checks the 5 HL7 values, MSH-11 included' do
    expect(Ehr::Settings::HL7_REQUIRED_SETTINGS).to contain_exactly(
      'HL7_SENDING_FACILITY', 'HL7_RECEIVING_FACILITY', 'HL7_PROCESSING_ID', 'HL7_DOCUMENT_TYPE', 'HL7_OBSERVATION_VALUE_PREFIX'
    )
  end

  Ehr::Settings::HL7_REQUIRED_SETTINGS.each do |setting|
    context "when #{setting} is blank" do
      include_context 'with environment variables', { setting => '' }

      let(:user) { create(:user, :confirmed, :participant, :with_hfhs_patient_detail) }

      before do
        allow(Sentry).to receive(:capture_message)
        allow(Rails.logger).to receive(:error)
      end

      it 'sends nothing, neither the answers nor the reports' do
        expect { described_class.new.perform(user_session.id) }.to raise_error(Ehr::Settings::MissingSettingError)

        expect(Api::Hl7Receiver).not_to have_received(:new)
        expect(api).not_to have_received(:send_answers)
        expect(api).not_to have_received(:send_reports)
      end

      it 'reports the missing setting by name to Sentry' do
        expect { described_class.new.perform(user_session.id) }.to raise_error(Ehr::Settings::MissingSettingError, /#{setting}/)

        expect(Sentry).to have_received(:capture_message).with(a_string_including(setting)).once
      end

      it 'fails the attempt so ActiveJob schedules a retry' do
        expect { perform_job }.to have_enqueued_job(described_class).with(user_session.id)
      end
    end
  end

  context 'when an HL7 setting is blank but the patient never verified their HFHS details' do
    include_context 'with environment variables', { 'HL7_DOCUMENT_TYPE' => '' }

    let(:user) { create(:user, :confirmed, :participant) }

    before { allow(Sentry).to receive(:capture_message) }

    it 'skips before the settings check: no error and no Sentry report' do
      expect { described_class.new.perform(user_session.id) }.not_to raise_error

      expect(Sentry).not_to have_received(:capture_message)
    end
  end

  context 'when an HL7 setting is blank but the participant is a verified test run' do
    include_context 'with environment variables', { 'HL7_DOCUMENT_TYPE' => '' }

    let(:user) do
      create(:user, :confirmed, :guest, :with_hfhs_patient_detail).tap do |guest|
        guest.update!(test_run: true, test_run_intervention_id: intervention.id)
      end
    end

    before { allow(Sentry).to receive(:capture_message) }

    it 'skips before the settings check: no error, no Sentry report, nothing sent' do
      expect { described_class.new.perform(user_session.id) }.not_to raise_error

      expect(Sentry).not_to have_received(:capture_message)
      expect(Api::Hl7Receiver).not_to have_received(:new)
    end
  end

  context 'when an HL7 setting would break the message' do
    include_context 'with environment variables', { 'HL7_RECEIVING_FACILITY' => 'HFH|X' }

    let(:user) { create(:user, :confirmed, :participant, :with_hfhs_patient_detail) }

    before do
      allow(Sentry).to receive(:capture_message)
      allow(Rails.logger).to receive(:error)
    end

    it 'sends nothing and reports the setting by name, never its value' do
      expect { described_class.new.perform(user_session.id) }.to raise_error(Ehr::Settings::InvalidSettingError, /HL7_RECEIVING_FACILITY/)

      expect(Api::Hl7Receiver).not_to have_received(:new)
      expect(Sentry).to have_received(:capture_message).with(a_string_including('HL7_RECEIVING_FACILITY')).once
      expect(Sentry).not_to have_received(:capture_message).with(a_string_including('HFH|X'))
    end
  end

  context 'when the session has already been purged' do
    let(:user) { create(:user, :confirmed, :participant) }

    it 'transmits nothing and does not raise' do
      id = user_session.id
      user_session.destroy!

      expect { described_class.perform_now(id) }.not_to raise_error
      expect(api).not_to have_received(:send_answers)
    end
  end
end
