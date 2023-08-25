# frozen_string_literal: true

RSpec.describe DataClearJobs::InformAndSchedule, type: :job do
  subject { described_class.perform_now(intervention.id, delay) }

  let!(:intervention) { create(:intervention, :with_pdf_report, :with_conversations_transcript, user: create(:user, :researcher)) }
  let!(:user_intervention2) { create(:user_intervention, intervention: intervention, user: create(:user, :guest, :confirmed)) }
  let(:delay) { 5 }

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  context 'with user intervention assigned to participant' do
    let!(:participant) { create(:user, :participant, :confirmed) }
    let!(:user_intervention1) { create(:user_intervention, intervention: intervention, user: participant) }

    it 'does enqueued job' do
      expect { subject }.to have_enqueued_job(DataClearJobs::ClearUserData).with(intervention.id)
    end

    it 'sends emails only for participants' do
      expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
      expect(ActionMailer::Base.deliveries.last.to).to eq [participant.email]
    end

    it 'correct email was called' do
      expect(InterventionMailer::ClearDataMailer).to receive(:inform)
      subject
    end

    context 'when delay is 0' do
      let(:delay) { 0 }

      it 'correct email was called' do
        expect(InterventionMailer::ClearDataMailer).to receive(:data_deleted)
        subject
      end
    end
  end

  context 'when guest has generated report and the system assigned it to the specially created for him participant account' do
    let!(:user_session) { create(:user_session, user_intervention: user_intervention2) }
    let!(:generated_report) { create(:generated_report, user_session: user_session, participant: new_participant) }
    let(:new_participant) { create(:user, :participant, :confirmed) }

    it 'sends emails only for participants' do
      expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
      expect(ActionMailer::Base.deliveries.last.to).to eq [new_participant.email]
    end

    context 'when user not confirmed his account' do
      let(:new_participant) { create(:user, :participant) }

      it 'doesn\'t send emails' do
        expect { subject }.not_to change { ActionMailer::Base.deliveries.size }
      end
    end
  end

  context 'generated reports for third party' do
    let(:session) { create(:session, :with_report_templates, intervention: intervention) }
    let(:third_party) { create(:user, :third_party, :confirmed) }
    let!(:user_session) { create(:user_session, user_intervention: user_intervention2) }
    let!(:generated_report) do
      create(:generated_report, user_session: user_session, report_template: session.report_templates.first,
                                generated_reports_third_party_users: [GeneratedReportsThirdPartyUser.create(third_party: third_party)])
    end

    it 'sends emails only for participants' do
      expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
      expect(ActionMailer::Base.deliveries.last.to).to eq [third_party.email]
    end

    context 'when third party user isn\'t confirmed' do
      let(:third_party) { create(:user, :third_party) }

      it 'doesn\'t send emails' do
        expect { subject }.not_to change { ActionMailer::Base.deliveries.size }
      end
    end
  end
end
