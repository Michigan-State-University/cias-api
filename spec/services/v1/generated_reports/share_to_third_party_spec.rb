# frozen_string_literal: true

RSpec.describe V1::GeneratedReports::ShareToThirdParty do
  subject { described_class.call(user_session) }

  let!(:user_session) { create(:user_session) }
  let!(:generated_report) { create(:generated_report, :third_party, user_session: user_session) }
  let!(:answer_third_party) do
    create(:answer_third_party, user_session: user_session,
                                body: { data: [{ value: 'johnny@example.com, johnny2@example.com' }] })
  end

  before do
    ActiveJob::Base.queue_adapter = :test
    Timecop.freeze
  end

  after do
    Timecop.return
  end

  context 'when users with the emails not exist in the system' do
    let(:new_user) { User.third_parties.first }

    it 'invites new users with third party role to the system, shares generated report with the users' do
      expect { subject }.to change(User, :count).by(2)
      expect(generated_report.reload.third_party_users).to include(new_user)

      expect(ActionMailer::MailDeliveryJob).to have_been_enqueued.twice
      expect(SendNewReportNotificationJob).to have_been_enqueued.at(Time.current + 30.seconds)
            .with(new_user.email)

      expect(new_user).to have_attributes(
        roles: ['third_party'],
        confirmed_at: nil
      )
    end
  end

  context 'when users with the emails provided in the third party screen already exist,
  and the users are third party' do
    let!(:user) { create(:user, :confirmed, :third_party, email: 'johnny@example.com') }
    let!(:user2) { create(:user, :confirmed, :third_party, email: 'johnny2@example.com') }

    it 'sends information about new report to the users, shared the report with the users' do
      expect { subject }.to change { generated_report.reload.third_party_users.order(:created_at) }.from([]).to(
        User.where(id: [user.id, user2.id]).order(:created_at)
      ).and \
        change { ActionMailer::Base.deliveries.size }.by(2).and \
          avoid_changing { User.count }
    end
  end

  context 'when report is not for third party' do
    before do
      generated_report.update!(report_for: 'participant')
    end

    it 'won\'t share report with third party' do
      expect { subject }.to avoid_changing { GeneratedReportsThirdPartyUser.count }.and \
        avoid_changing { ActionMailer::Base.deliveries.size }.and \
          avoid_changing { User.count }
    end
  end

  context 'when email is not provided in the third party screen' do
    before do
      answer_third_party.update(body: { data: [{ value: '' }] })
    end

    it 'won\'t share report with third party' do
      expect { subject }.to avoid_changing { GeneratedReportsThirdPartyUser.count }.and \
        avoid_changing { ActionMailer::Base.deliveries.size }.and \
          avoid_changing { User.count }
    end
  end

  context 'when there is no third party screen' do
    before do
      answer_third_party.destroy
    end

    it 'won\'t share report with third party' do
      expect { subject }.to avoid_changing { GeneratedReportsThirdPartyUser.count }.and \
        avoid_changing { ActionMailer::Base.deliveries.size }.and \
          avoid_changing { User.count }
    end
  end

  context 'when users with provided emails are researchers' do
    let!(:user) { create(:user, :confirmed, :researcher, email: 'johnny@example.com') }
    let!(:user2) { create(:user, :confirmed, :researcher, email: 'johnny2@example.com') }

    it 'won\'t share report with third party' do
      expect { subject }.to avoid_changing { GeneratedReportsThirdPartyUser.count }.and \
        avoid_changing { ActionMailer::Base.deliveries.size }.and \
          avoid_changing { User.count }
    end
  end

  context 'when users are third party but with deactivated accounts' do
    let!(:user) { create(:user, :confirmed, :third_party, email: 'johnny@example.com', active: false) }
    let!(:user2) { create(:user, :confirmed, :third_party, email: 'johnny2@example.com', active: false) }

    it 'share report with third party but avoid sending email about new report' do
      expect { subject }.to change { generated_report.reload.third_party_users.order(:created_at) }.from([]).to(
        User.where(id: [user.id, user2.id]).order(:created_at)
      ).and \
        avoid_changing { ActionMailer::Base.deliveries.size }.and \
          avoid_changing { User.count }
    end
  end

  context "when third party user doesn't have enabled email notifications" do
    let!(:user) { create(:user, :confirmed, :third_party, email: 'johnny@example.com', email_notification: false) }

    it "don't send email" do
      expect { subject }.to avoid_changing { ActionMailer::Base.deliveries.size }
    end
  end
end
