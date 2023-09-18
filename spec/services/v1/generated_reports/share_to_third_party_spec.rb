# frozen_string_literal: true

shared_examples 'user third_party role invitation, generating report sharing' do |user_number, generated_reports_third_party_user_number, mail_number|
  it 'invites new users with third party role to the system, shares generated report with the users' do
    expect { subject }.to change(User, :count).by(user_number).and \
      change(GeneratedReportsThirdPartyUser, :count).by(generated_reports_third_party_user_number)
    expect(SendNewReportNotificationJob).to have_been_enqueued.exactly(mail_number)
  end
end

RSpec.describe V1::GeneratedReports::ShareToThirdParty do
  subject { described_class.call(user_session) }

  let!(:user_session) { create(:user_session) }
  let!(:generated_report) { create(:generated_report, :third_party, user_session: user_session) }
  let!(:answer_third_party) do
    create(:answer_third_party, user_session: user_session,
                                body: { data: [{ value: 'johnny@example.com, johnny2@example.com',
                                                 report_template_ids: [generated_report.report_template.id],
                                                 index: 0 }] })
  end

  before do
    ActiveJob::Base.queue_adapter = :test
    Timecop.freeze
  end

  after do
    Timecop.return
  end

  shared_examples "won't share report with third party" do
    it 'won\'t share report with third party' do
      expect { subject }.to avoid_changing { GeneratedReportsThirdPartyUser.count }.and \
        avoid_changing { ActionMailer::Base.deliveries.size }.and \
          avoid_changing { User.count }
    end
  end

  context 'when users with the emails not exist in the system' do
    let(:new_user) { User.third_parties.first }
    let(:number_of_generated_reports) { 1 }

    it 'invites new users with third party role to the system, shares generated report with the users' do
      expect { subject }.to change(User, :count).by(2)
      expect(generated_report.reload.third_party_users).to include(new_user)

      expect(ActionMailer::MailDeliveryJob).to have_been_enqueued.twice
      expect(SendNewReportNotificationJob).to have_been_enqueued.at(Time.current + 30.seconds)
            .with(new_user.email, number_of_generated_reports)

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

    it_behaves_like "won't share report with third party"
  end

  context 'when email is not provided in the third party screen' do
    before do
      answer_third_party.update(body: { data: [{ value: '', report_template_ids: [generated_report.report_template.id], index: 0 }] })
    end

    it_behaves_like "won't share report with third party"
  end

  context 'when report_template id is not provided in the third party screen' do
    before do
      answer_third_party.update(body: { data: [{ value: 'johnny@example.com, johnny2@example.com', report_template_ids: [], index: 0 }] })
    end

    it_behaves_like "won't share report with third party"
  end

  context 'when there is no third party screen' do
    before do
      answer_third_party.destroy
    end

    it_behaves_like "won't share report with third party"
  end

  context 'when users with provided emails are researchers' do
    let!(:user) { create(:user, :confirmed, :researcher, email: 'johnny@example.com') }
    let!(:user2) { create(:user, :confirmed, :researcher, email: 'johnny2@example.com') }

    it_behaves_like "won't share report with third party"
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

  context 'when user_session has many generated reports' do
    let!(:generated_report2) { create(:generated_report, :third_party, user_session: user_session) }
    let!(:generated_report3) { create(:generated_report, :third_party, user_session: user_session) }

    context 'when users don\'t exist in the system' do
      context 'when the same email occurs in two different answers with two different report templates' do
        let!(:answer_third_party2) do
          create(:answer_third_party, user_session: user_session,
                                      body: { data: [{ value: 'johnny@example.com, johnny2@example.com',
                                                       report_template_ids: [generated_report2.report_template.id], index: 0 }] })
        end

        it_behaves_like 'user third_party role invitation, generating report sharing', 2, 4, 2
      end

      context 'when many emails occurs with many report templates in one answer' do
        let!(:answer_third_party) do
          create(:answer_third_party, user_session: user_session,
                                      body: { data: [{ value: 'johnny@example.com, johnny2@example.com',
                                                       report_template_ids: [generated_report.report_template.id, generated_report2.report_template.id],
                                                       index: 0 }] })
        end

        it_behaves_like 'user third_party role invitation, generating report sharing', 2, 4, 2
      end

      context 'when many emails have many different report templates' do
        let!(:generated_report4) { create(:generated_report, :third_party, user_session: user_session) }
        let!(:answer_third_party) do
          create(:answer_third_party, user_session: user_session,
                                      body: { data: [{ value: 'johnny@example.com, johnny2@example.com',
                                                       report_template_ids: [generated_report.report_template.id, generated_report2.report_template.id],
                                                       index: 0 }] })
        end
        let!(:answer_third_party2) do
          create(:answer_third_party, user_session: user_session,
                                      body: { data: [{ value: 'johnny3@example.com, johnny2@example.com',
                                                       report_template_ids: [generated_report3.report_template.id], index: 0 }] })
        end

        it_behaves_like 'user third_party role invitation, generating report sharing', 3, 6, 3
      end
    end

    context 'when users exists in the system' do
      let!(:user) { create(:user, :confirmed, :third_party, email: 'johnny@example.com') }
      let!(:user2) { create(:user, :confirmed, :third_party, email: 'johnny2@example.com') }

      context 'when the same email occurs in two different answers with two different report templates' do
        let!(:answer_third_party2) do
          create(:answer_third_party, user_session: user_session,
                                      body: { data: [{ value: 'johnny@example.com, johnny2@example.com',
                                                       report_template_ids: [generated_report2.report_template.id], index: 0 }] })
        end

        it 'sends information about new report to the users, shared the report with the users' do
          expect { subject }.to change { generated_report.reload.third_party_users.order(:created_at) }.from([]).to(
            User.where(id: [user.id, user2.id]).order(:created_at)
          ).and \
            change { generated_report2.reload.third_party_users.order(:created_at) }.from([]).to(
              User.where(id: [user.id, user2.id]).order(:created_at)
            ).and \
              change { ActionMailer::Base.deliveries.size }.by(2).and \
                avoid_changing { User.count }
        end
      end

      context 'when many emails occurs with many report templates in one answer' do
        let!(:answer_third_party) do
          create(:answer_third_party, user_session: user_session,
                                      body: { data: [{ value: 'johnny@example.com, johnny2@example.com',
                                                       report_template_ids: [generated_report.report_template.id, generated_report2.report_template.id],
                                                       index: 0 }] })
        end

        it 'sends information about new report to the users, shared the report with the users' do
          expect { subject }.to change { generated_report.reload.third_party_users.order(:created_at) }.from([]).to(
            User.where(id: [user.id, user2.id]).order(:created_at)
          ).and \
            change { ActionMailer::Base.deliveries.size }.by(2).and \
              avoid_changing { User.count }
        end
      end

      context 'when instead of emails is provided fax number' do
        let!(:answer_third_party) do
          create(:answer_third_party, user_session: user_session,
                                      body: { data: [{ value: '+1202-222-2243',
                                                       report_template_ids: [generated_report.report_template.id], index: 0 }] })
        end

        before do
          allow_any_instance_of(Api::Documo::SendMultipleFaxes).to receive(:call)
                                                                     .and_return(true)
        end

        it 'call service' do
          receiver_label = ''
          fields = generated_report.report_template.slice(:cover_letter_description, :cover_letter_sender, :name)
                                                  .merge({ receiver: ActionView::Base.full_sanitizer.sanitize(receiver_label) })

          expect(Api::Documo::SendMultipleFaxes).to receive(:call).with(['+1202-222-2243'], [kind_of(ActiveStorage::Attached::One)], false, fields,
                                                                        kind_of(ActiveStorage::Attached::One))
          subject
        end
      end

      context 'multiple fax numbers and one generated report' do
        let!(:answer_third_party) do
          create(:answer_third_party, user_session: user_session,
                                      body: { data: [{ value: '+1202-222-2243,+1202-222-2222',
                                                       report_template_ids: [generated_report.report_template.id], index: 0 }] })
        end

        before do
          allow_any_instance_of(Api::Documo::SendMultipleFaxes).to receive(:call)
                                                                     .and_return(true)
        end

        it 'call service' do
          receiver_label = ''
          fields = generated_report.report_template.slice(:cover_letter_description, :cover_letter_sender, :name)
                                   .merge({ receiver: ActionView::Base.full_sanitizer.sanitize(receiver_label) })

          expect(Api::Documo::SendMultipleFaxes).to receive(:call).with(%w[+1202-222-2243 +1202-222-2222], [kind_of(ActiveStorage::Attached::One)], false,
                                                                        fields, kind_of(ActiveStorage::Attached::One))
          subject
        end
      end

      context 'one fax number and multipe generated reports' do
        let!(:generated_report2) { create(:generated_report, :third_party, user_session: user_session) }
        let!(:answer_third_party) do
          create(:answer_third_party, user_session: user_session,
                                      body: { data: [{ value: '+1202-222-2222',
                                                       report_template_ids: [generated_report.report_template.id, generated_report2.report_template.id],
                                                       index: 0 }] })
        end

        before do
          allow_any_instance_of(Api::Documo::SendMultipleFaxes).to receive(:call)
                                                                     .and_return(true)
        end

        it 'call service' do
          expect(Api::Documo::SendMultipleFaxes).to receive(:call).twice
          subject
        end
      end

      context 'when many emails have many different report templates' do
        let!(:user3) { create(:user, :confirmed, :third_party, email: 'johnny3@example.com') }
        let!(:generated_report4) { create(:generated_report, :third_party, user_session: user_session) }
        let!(:answer_third_party) do
          create(:answer_third_party, user_session: user_session,
                                      body: { data: [{ value: 'johnny@example.com, johnny2@example.com',
                                                       report_template_ids: [generated_report.report_template.id, generated_report2.report_template.id],
                                                       index: 0 }] })
        end
        let!(:answer_third_party2) do
          create(:answer_third_party, user_session: user_session,
                                      body: { data: [{ value: 'johnny3@example.com, johnny2@example.com',
                                                       report_template_ids: [generated_report3.report_template.id], index: 0 }] })
        end

        it 'sends information about new report to the users, shared the report with the users' do
          expect { subject }.to change { generated_report.reload.third_party_users.order(:created_at) }.from([]).to(
            User.where(id: [user.id, user2.id]).order(:created_at)
          ).and \
            change { generated_report2.reload.third_party_users.order(:created_at) }.from([]).to(
              User.where(id: [user.id, user2.id]).order(:created_at)
            ).and \
              change { generated_report3.reload.third_party_users.order(:created_at) }.from([]).to(
                User.where(id: [user2.id, user3.id]).order(:created_at)
              ).and \
                change { ActionMailer::Base.deliveries.size }.by(3).and \
                  avoid_changing { User.count }
        end
      end
    end
  end
end
