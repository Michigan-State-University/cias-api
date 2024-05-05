# frozen_string_literal: true

RSpec.describe UserSessionJobs::ScheduleDailyMessagesJob, type: :job do
  subject { described_class.perform_now(user_session.id) }

  before do
    ActiveJob::Base.queue_adapter = :test
    allow_any_instance_of(Communication::Sms).to receive(:send_message).and_return(
      {
        status: 200
      }
    )
  end

  describe '#perform_later' do
    let!(:user) { create(:user, :with_phone) }
    let!(:intervention) { create(:intervention) }
    let!(:session) { create(:sms_session, sms_code: 'SMS_CODE_1', intervention: intervention, question_group_initial: question_group_initial) }
    let!(:user_intervention) { create(:user_intervention, user: user, intervention: intervention) }
    let!(:user_session) { create(:sms_user_session, user: user, session: session) }

    context 'when only one question group is created without any formulas and one question per day' do
      let!(:question_group_initial) do
        build(:question_group_initial,
              formulas: [],
              sms_schedule: {
                period: 'weekly',
                day_of_period: ['1'],
                questions_per_day: 1,
                time: {
                  exact: '8:00 AM'
                }
              })
      end

      context 'when only one question is created' do
        let!(:question_sms_information) { create(:question_sms_information, question_group: question_group_initial) }

        context 'when today is desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'schedules sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 1).change({ hour: 7 }) do
              expect { subject }.to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob)
            end
          end
        end

        context 'when today is NOT desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'does not schedule sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 2) do
              expect { subject }.not_to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob)
            end
          end
        end
      end

      context 'when multiple questions are created' do
        let!(:question_sms_information) { create(:question_sms_information, question_group: question_group_initial) }
        let!(:question_sms_information2) { create(:question_sms_information, question_group: question_group_initial) }
        let!(:question_sms_information3) { create(:question_sms_information, question_group: question_group_initial) }

        context 'when today is desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'schedules sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 1).change({ hour: 7 }) do
              expect { subject }.to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob)
            end
          end
        end

        context 'when today is NOT desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'does not schedule sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 2) do
              expect { subject }.not_to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob)
            end
          end
        end
      end
    end

    context 'when only one question group is created without any formulas and two questions per day' do
      let!(:question_group_initial) do
        build(:question_group_initial,
              formulas: [],
              sms_schedule: {
                period: 'weekly',
                day_of_period: ['1'],
                questions_per_day: 2,
                time: {
                  exact: '8:00 AM'
                }
              })
      end

      context 'when only one question is created' do
        let!(:question_sms_information) { create(:question_sms_information, question_group: question_group_initial) }

        context 'when today is desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'schedules sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 1).change({ hour: 7 }) do
              expect { subject }.to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob).at_least(2).times
            end
          end
        end

        context 'when today is NOT desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'does not schedule sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 2) do
              expect { subject }.not_to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob)
            end
          end
        end
      end

      context 'when multiple SmsInformation questions are created' do
        let!(:question_sms_information) { create(:question_sms_information, question_group: question_group_initial) }
        let!(:question_sms_information2) { create(:question_sms_information, question_group: question_group_initial) }
        let!(:question_sms_information3) { create(:question_sms_information, question_group: question_group_initial) }

        context 'when today is desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'schedules sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 1).change({ hour: 7 }) do
              expect { subject }.to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob).at_least(2).times
            end
          end
        end

        context 'when today is NOT desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'does not schedule sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 2) do
              expect { subject }.not_to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob)
            end
          end
        end
      end

      context 'when multiple Sms questions are created' do
        let!(:question_sms) { create(:question_sms, question_group: question_group_initial) }
        let!(:question_sms2) { create(:question_sms, question_group: question_group_initial) }
        let!(:question_sms3) { create(:question_sms, question_group: question_group_initial) }

        context 'when today is desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'schedules sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 1).change({ hour: 7 }) do
              expect { subject }.to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob).at_least(2).times
            end
          end
        end

        context 'when today is NOT desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'does not schedule sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 2) do
              expect { subject }.not_to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob)
            end
          end
        end
      end

      context 'when multiple Sms and SmsInformation questions are created' do
        let!(:question_sms) { create(:question_sms, question_group: question_group_initial) }
        let!(:question_sms2) { create(:question_sms, question_group: question_group_initial) }
        let!(:question_sms3) { create(:question_sms, question_group: question_group_initial) }
        let!(:question_sms_information) { create(:question_sms_information, question_group: question_group_initial) }
        let!(:question_sms_information2) { create(:question_sms_information, question_group: question_group_initial) }
        let!(:question_sms_information3) { create(:question_sms_information, question_group: question_group_initial) }

        context 'when today is desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'schedules sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 1).change({ hour: 7 }) do
              expect { subject }.to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob).at_least(2).times
            end
          end
        end

        context 'when today is NOT desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'does not schedule sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 2) do
              expect { subject }.not_to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob)
            end
          end
        end
      end
    end

    context 'when multiple question groups are created without any formulas, scheduled for the same day and one question per day' do
      let!(:question_group_initial) do
        build(:question_group_initial,
              formulas: [],
              sms_schedule: {
                period: 'weekly',
                day_of_period: ['1'],
                questions_per_day: 1,
                time: {
                  exact: '8:00 AM'
                }
              })
      end
      let!(:question_group) do
        create(:sms_question_group,
               session: session,
               formulas: [],
               sms_schedule: {
                 period: 'weekly',
                 day_of_period: ['1'],
                 questions_per_day: 1,
                 time: {
                   exact: '8:00 AM'
                 }
               })
      end

      context 'when only one question per question group is created' do
        let!(:question_sms_information) { create(:question_sms_information, question_group: question_group_initial) }
        let!(:question_sms_information2) { create(:question_sms_information, question_group: question_group) }

        context 'when today is desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'schedules sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 1).change({ hour: 7 }) do
              expect { subject }.to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob).at_least(2).times
            end
          end
        end

        context 'when today is NOT desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'does not schedule sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 2) do
              expect { subject }.not_to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob)
            end
          end
        end
      end

      context 'when multiple SmsInformation questions per question group are created' do
        let!(:question_sms_information) { create(:question_sms_information, question_group: question_group_initial) }
        let!(:question_sms_information2) { create(:question_sms_information, question_group: question_group_initial) }
        let!(:question_sms_information3) { create(:question_sms_information, question_group: question_group_initial) }
        let!(:question_sms_information4) { create(:question_sms_information, question_group: question_group) }
        let!(:question_sms_information5) { create(:question_sms_information, question_group: question_group) }
        let!(:question_sms_information6) { create(:question_sms_information, question_group: question_group) }

        context 'when today is desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'schedules sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 1).change({ hour: 7 }) do
              expect { subject }.to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob).at_least(2).times
            end
          end
        end

        context 'when today is NOT desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'does not schedule sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 2) do
              expect { subject }.not_to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob)
            end
          end
        end
      end

      context 'when multiple Sms questions per question group are created' do
        let!(:question_sms) { create(:question_sms, question_group: question_group_initial) }
        let!(:question_sms2) { create(:question_sms, question_group: question_group_initial) }
        let!(:question_sms3) { create(:question_sms, question_group: question_group_initial) }
        let!(:question_sms4) { create(:question_sms, question_group: question_group) }
        let!(:question_sms5) { create(:question_sms, question_group: question_group) }
        let!(:question_sms6) { create(:question_sms, question_group: question_group) }

        context 'when today is desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'schedules sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 1).change({ hour: 7 }) do
              expect { subject }.to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob).at_least(2).times
            end
          end
        end

        context 'when today is NOT desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'does not schedule sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 2) do
              expect { subject }.not_to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob)
            end
          end
        end
      end

      context 'when multiple Sms and SmsInformation questions per question group are created' do
        let!(:question_sms) { create(:question_sms, question_group: question_group_initial) }
        let!(:question_sms2) { create(:question_sms, question_group: question_group_initial) }
        let!(:question_sms3) { create(:question_sms, question_group: question_group_initial) }
        let!(:question_sms_information) { create(:question_sms_information, question_group: question_group_initial) }
        let!(:question_sms_information2) { create(:question_sms_information, question_group: question_group_initial) }
        let!(:question_sms_information3) { create(:question_sms_information, question_group: question_group_initial) }
        let!(:question_sms4) { create(:question_sms, question_group: question_group) }
        let!(:question_sms5) { create(:question_sms, question_group: question_group) }
        let!(:question_sms6) { create(:question_sms, question_group: question_group) }
        let!(:question_sms_information4) { create(:question_sms_information, question_group: question_group) }
        let!(:question_sms_information5) { create(:question_sms_information, question_group: question_group) }
        let!(:question_sms_information6) { create(:question_sms_information, question_group: question_group) }

        context 'when today is desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'schedules sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 1).change({ hour: 7 }) do
              expect { subject }.to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob).at_least(2).times
            end
          end
        end

        context 'when today is NOT desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'does not schedule sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 2) do
              expect { subject }.not_to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob)
            end
          end
        end
      end
    end

    context 'when multiple question groups are created with conditional formulas, scheduled for the same day and one question per day' do
      let!(:question_group_initial) do
        build(:question_group_initial,
              formulas: [],
              sms_schedule: {
                period: 'weekly',
                day_of_period: ['1'],
                questions_per_day: 1,
                time: {
                  exact: '8:00 AM'
                }
              })
      end
      let!(:question_group) do
        create(:sms_question_group,
               session: session,
               formulas: [
                 {
                   'payload' => 'var',
                   'patterns' => [{ 'match' => '=3' }]
                 }
               ],
               sms_schedule: {
                 period: 'weekly',
                 day_of_period: ['2'],
                 questions_per_day: 1,
                 time: {
                   exact: '8:00 AM'
                 }
               })
      end
      let!(:question_group2) do
        create(:sms_question_group,
               session: session,
               formulas: [
                 {
                   'payload' => 'var',
                   'patterns' => [{ 'match' => '=4' }]
                 }
               ],
               sms_schedule: {
                 period: 'weekly',
                 day_of_period: ['2'],
                 questions_per_day: 1,
                 time: {
                   exact: '8:00 AM'
                 }
               })
      end
      let!(:control_question) { create(:question_sms, question_group: question_group_initial) }
      let!(:control_question_answer) do
        create(:answer_sms,
               question: control_question,
               user_session: user_session,
               body: {
                 data: [{ value: '3', var: 'var' }]
               })
      end

      context 'when only one question per question group is created' do
        let!(:question_sms_information) { create(:question_sms_information, question_group: question_group) }
        let!(:question_sms_information2) { create(:question_sms_information, question_group: question_group2) }

        context 'when today is desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'schedules sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 2).change({ hour: 7 }) do
              expect { subject }.to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob)
                                      .with(user.id, question_sms_information.id, user_session.id)
            end
          end
        end

        context 'when today is NOT desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'does not schedule sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 3) do
              expect { subject }.not_to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob)
            end
          end
        end
      end

      context 'when multiple SmsInformation questions per question group are created' do
        let!(:question_sms_information) { create(:question_sms_information, question_group: question_group) }
        let!(:question_sms_information2) { create(:question_sms_information, question_group: question_group) }
        let!(:question_sms_information3) { create(:question_sms_information, question_group: question_group) }
        let!(:question_sms_information4) { create(:question_sms_information, question_group: question_group2) }
        let!(:question_sms_information5) { create(:question_sms_information, question_group: question_group2) }
        let!(:question_sms_information6) { create(:question_sms_information, question_group: question_group2) }

        context 'when today is desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'schedules sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 2).change({ hour: 7 }) do
              expect { subject }.to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob)
                                      .with(user.id, question_sms_information.id, user_session.id)
            end
          end
        end

        context 'when today is NOT desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'does not schedule sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 3) do
              expect { subject }.not_to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob)
            end
          end
        end
      end

      context 'when multiple Sms questions per question group are created' do
        let!(:question_sms) { create(:question_sms, question_group: question_group) }
        let!(:question_sms2) { create(:question_sms, question_group: question_group) }
        let!(:question_sms3) { create(:question_sms, question_group: question_group) }
        let!(:question_sms4) { create(:question_sms, question_group: question_group2) }
        let!(:question_sms5) { create(:question_sms, question_group: question_group2) }
        let!(:question_sms6) { create(:question_sms, question_group: question_group2) }

        context 'when today is desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'schedules sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 2).change({ hour: 7 }) do
              expect { subject }.to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob)
                                      .with(user.id, question_sms.id, user_session.id)
            end
          end
        end

        context 'when today is NOT desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'does not schedule sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 3) do
              expect { subject }.not_to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob)
            end
          end
        end
      end

      context 'when multiple Sms and SmsInformation questions per question group are created' do
        let!(:question_sms_information) { create(:question_sms_information, question_group: question_group) }
        let!(:question_sms_information2) { create(:question_sms_information, question_group: question_group) }
        let!(:question_sms_information3) { create(:question_sms_information, question_group: question_group) }
        let!(:question_sms_information4) { create(:question_sms_information, question_group: question_group2) }
        let!(:question_sms_information5) { create(:question_sms_information, question_group: question_group2) }
        let!(:question_sms_information6) { create(:question_sms_information, question_group: question_group2) }
        let!(:question_sms) { create(:question_sms, question_group: question_group) }
        let!(:question_sms2) { create(:question_sms, question_group: question_group) }
        let!(:question_sms3) { create(:question_sms, question_group: question_group) }
        let!(:question_sms4) { create(:question_sms, question_group: question_group2) }
        let!(:question_sms5) { create(:question_sms, question_group: question_group2) }
        let!(:question_sms6) { create(:question_sms, question_group: question_group2) }

        context 'when today is desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'schedules sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 2).change({ hour: 7 }) do
              expect { subject }.to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob)
                                      .with(user.id, question_group.questions.order(:position).first.id, user_session.id)
            end
          end
        end

        context 'when today is NOT desired day' do
          include ActiveSupport::Testing::TimeHelpers

          it 'does not schedule sms sending job' do
            travel_to DateTime.commercial(Date.current.year, Date.current.cweek + 1, 3) do
              expect { subject }.not_to have_enqueued_job(UserSessionJobs::SendQuestionSmsJob)
            end
          end
        end
      end
    end
  end
end
