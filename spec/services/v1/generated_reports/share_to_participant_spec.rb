# frozen_string_literal: true

RSpec.describe V1::GeneratedReports::ShareToParticipant do
  subject { described_class.call(user_session) }

  let!(:user_session) { create(:user_session, user: create(:user, :confirmed, :guest)) }
  let!(:participant_report) { create(:generated_report, :participant, user_session: user_session) }
  let!(:answer_participant_report) do
    create(:answer_participant_report, user_session: user_session,
                                       body: { data: [{ value: { receive_report: true, email: 'johnny@example.com' } }] })
  end

  before do
    ActiveJob::Base.queue_adapter = :test
    Timecop.freeze
  end

  after do
    Timecop.return
  end

  context 'when there is participant report' do
    context 'and guest user wants to receive the report' do
      context 'provided email not exist in the system' do
        let(:new_participant) { User.participants.order(created_at: :desc).first }

        it 'creates new user with participant role and given email, shares report to that user
        and sends an invitation email and an email about new report' do
          expect { subject }.to change(User, :count).by(1)

          expect(ActionMailer::MailDeliveryJob).to have_been_enqueued
          expect(SendNewReportNotificationJob).to have_been_enqueued.at(30.seconds.from_now)
            .with(new_participant.email, 'en')

          expect(participant_report.reload.participant_id).to eq(new_participant.id)
        end
      end

      context 'provided email exists in the system and it\'s participant email' do
        let!(:participant) { create(:user, :confirmed, :participant, email: 'johnny@example.com') }

        it 'shares report to existing user and sends an email about new report' do
          expect { subject }.to avoid_changing { User.count }.and \
            change { ActionMailer::Base.deliveries.size }.by(1)

          expect(participant_report.reload.participant_id).to eq(participant.id)
        end
      end

      context 'provided email exists in the system and it\'s not participant email' do
        let!(:researcher) { create(:user, :confirmed, :researcher, email: 'johnny@example.com') }

        it 'does not create new user, does not share report with the user' do
          expect { subject }.to avoid_changing { User.count }.and \
            avoid_changing { ActionMailer::Base.deliveries.size }.and \
              avoid_changing { participant_report.reload.participant_id }
        end
      end

      context 'email is not provided' do
        before do
          answer_participant_report.update(body: { data: [{ value: { receive_report: true, email: '' } }] })
        end

        it 'does not create new user, does not share report with the user' do
          expect { subject }.to avoid_changing { User.count }.and \
            avoid_changing { ActionMailer::Base.deliveries.size }.and \
              avoid_changing { participant_report.reload.participant_id }
        end
      end
    end

    context 'guest does not want to receive the report' do
      before do
        answer_participant_report.update(body: { data: [{ value: { receive_report: false,
                                                                   email: 'johhny@example.com' } }] })
      end

      it 'does not create new user, does not share report with the user' do
        expect { subject }.to avoid_changing { User.count }.and \
          avoid_changing { ActionMailer::Base.deliveries.size }.and \
            avoid_changing { participant_report.reload.participant_id }
      end
    end

    context 'when there is no participant screen' do
      before do
        answer_participant_report.destroy
      end

      it 'does not create new user, does not share report with the user' do
        expect { subject }.to avoid_changing { User.count }.and \
          avoid_changing { ActionMailer::Base.deliveries.size }.and \
            avoid_changing { participant_report.reload.participant_id }
      end
    end

    context 'when logged in user is participant' do
      let(:participant) { create(:user, :confirmed, :participant) }

      before do
        user_session.update(user: participant)
      end

      it 'does not create new user, shares report with the logged in user and
      sends information about report to that user' do
        expect { subject }.to avoid_changing { User.count }.and \
          change { ActionMailer::Base.deliveries.size }.by(1)

        expect(participant_report.reload.participant_id).to eq(participant.id)
        expect(ActionMailer::Base.deliveries.first).to have_attributes(
          to: include(participant.email),
          subject: 'New reports in the system are ready for you'
        )
      end
    end

    context 'when user role is different than guest and participant' do
      let(:researcher) { create(:user, :confirmed, :researcher) }

      before do
        user_session.update(user: researcher)
      end

      it 'does not create new user, does not share report with the user' do
        expect { subject }.to avoid_changing { User.count }.and \
          avoid_changing { ActionMailer::Base.deliveries.size }.and \
            avoid_changing { participant_report.reload.participant_id }
      end
    end
  end

  context 'when there is no participant report for user session' do
    let!(:third_party_report) { create(:generated_report, :third_party, user_session: user_session) }

    before do
      participant_report.destroy
    end

    it 'does not create new user, does not share report with the user' do
      expect { subject }.to avoid_changing { User.count }.and \
        avoid_changing { ActionMailer::Base.deliveries.size }.and \
          avoid_changing { third_party_report.reload.participant_id }
    end
  end

  context 'when user has disabled email notifications' do
    let!(:participant) { create(:user, :confirmed, :participant, email: 'johnny@example.com') }

    it "Don't send email" do
      expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
    end
  end

  context 'when user has enabled email notifications' do
    let!(:participant) do
      create(:user, :confirmed, :participant, email: 'johnny@example.com', email_notification: false)
    end

    it 'send email' do
      expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(0)
    end
  end
end
