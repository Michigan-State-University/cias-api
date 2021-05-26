# frozen_string_literal: true

RSpec.describe V1::UserSessionScheduleService do
  let!(:intervention) { create(:intervention, :published) }
  let!(:user) { create(:user, :participant) }
  let!(:first_session) do
    create(:session, intervention: intervention, position: 1, settings: settings, formula: formula)
  end
  let!(:second_session) do
    create(:session, intervention: intervention, schedule: schedule, schedule_payload: schedule_payload, position: 2,
                     schedule_at: schedule_at)
  end
  let!(:third_session) { create(:session, intervention: intervention, position: 3) }
  let!(:user_session) { create(:user_session, user: user, session: first_session) }
  let(:schedule) { 'after_fill' }
  let(:schedule_payload) { 2 }
  let(:schedule_at) { (DateTime.now + 4.days).to_s }
  let(:message_delivery) { instance_double(ActionMailer::MessageDelivery) }
  let(:settings) { { formula: false } }
  let(:formula) { { patterns: [], payload: '' } }

  before do
    allow(message_delivery).to receive(:deliver_later)
    ActiveJob::Base.queue_adapter = :test
  end

  context 'user session schedule service' do
    context 'session scheduling' do
      context 'when session has schedule after fill' do
        after { described_class.new(user_session).schedule }

        it 'calls correct method' do
          expect_any_instance_of(described_class).to receive(:after_fill_schedule)
        end

        it 'sends an email' do
          allow(SessionMailer).to receive(:inform_to_an_email).with(second_session,
                                                                    user.email).and_return(message_delivery)
        end
      end

      context 'when session has schedule days after fill' do
        let(:schedule) { 'days_after_fill' }
        let(:expected_timestamp) { Time.current + schedule_payload.days }

        it 'calls correct method' do
          expect_any_instance_of(described_class).to receive(:days_after_fill_schedule)
          described_class.new(user_session).schedule
        end

        it 'schedules on correct time' do
          expect { described_class.new(user_session).schedule }.to have_enqueued_job(SessionEmailScheduleJob)
                                                 .with(second_session.id, user.id)
                                                 .at(a_value_within(1.second).of(expected_timestamp))
        end
      end

      context 'when session has schedule exact date' do
        let(:schedule) { 'exact_date' }

        it 'calls correct method' do
          expect_any_instance_of(described_class).to receive(:exact_date_schedule)
          described_class.new(user_session).schedule
        end

        it 'schedules on correct time' do
          expect { described_class.new(user_session).schedule }.to have_enqueued_job(SessionEmailScheduleJob)
                                                                     .with(second_session.id, user.id)
                                                                     .at(a_value_within(1.second).of(Date.parse(schedule_at).noon))
        end
      end

      context 'when session has schedule days_after' do
        let(:schedule) { 'days_after' }

        it 'calls correct method' do
          expect_any_instance_of(described_class).to receive(:days_after_schedule)
          described_class.new(user_session).schedule
        end

        it 'schedules on correct time' do
          expect { described_class.new(user_session).schedule }.to have_enqueued_job(SessionEmailScheduleJob)
                                                                     .with(second_session.id, user.id)
                                                                     .at(a_value_within(1.second).of(Date.parse(schedule_at).noon))
        end
      end

      context 'when session has schedule days_after_date' do
        let(:schedule) { 'days_after_date' }
        let(:tomorrow) { DateTime.now.tomorrow }

        context 'when days_after_date_variable is given' do
          let!(:update_second_session) do
            second_session.update(days_after_date_variable_name: 'days_after_date_variable')
          end
          let!(:answer) do
            create(:answer_date, user_session: user_session,
                                 body: { data: [{ var: 'days_after_date_variable', value: tomorrow.to_s }] })
          end

          it 'calls correct method' do
            expect_any_instance_of(described_class).to receive(:days_after_date_schedule)
            described_class.new(user_session).schedule
          end

          it 'schedules on correct time' do
            expect { described_class.new(user_session).schedule }.to have_enqueued_job(SessionEmailScheduleJob)
                                                                         .with(second_session.id, user.id)
                                                                         .at(a_value_within(1.second).of((tomorrow + schedule_payload.days).noon))
          end
        end

        context 'when days_after_date_variable is not given' do
          let!(:answer) { create(:answer_date, user_session: user_session) }

          it 'calls correct method' do
            expect_any_instance_of(described_class).to receive(:days_after_date_schedule)
            described_class.new(user_session).schedule
          end

          it 'does not schedule' do
            expect(described_class.new(user_session).schedule).to eq(nil)
          end
        end
      end
    end

    context 'session branching' do
      let(:instance) { described_class.new(user_session) }

      context 'formula settings is off' do
        context 'formula is empty' do
          it 'returns next session id' do
            expect(instance.branch_to_session.id).to eq(second_session.id)
          end
        end

        context 'formula is set up' do
          let(:question_group) { create(:question_group, session: first_session) }
          let(:question) { create(:question_single, question_group: question_group) }
          let!(:answer) { create(:answer_single, question: question, user_session: user_session) }
          let(:formula) do
            {
              payload: 'test',
              patterns: [{
                match: '=2',
                target: [{
                  id: second_session.id,
                  probability: '100',
                  type: 'Session'
                }]
              },
                         {
                           match: '=1',
                           target: [{
                             id: third_session.id,
                             probability: '100',
                             type: 'Session'
                           }]
                         }]
            }
          end

          it 'returns next session id' do
            expect(instance.branch_to_session.id).to eq(second_session.id)
          end
        end
      end

      context 'formula settings is on' do
        let(:settings) { { formula: true } }

        context 'branching is empty' do
          it 'returns next session id' do
            expect(instance.branch_to_session.id).to eq(second_session.id)
          end
        end

        context 'branching is set up' do
          let(:question_group) { create(:question_group, session: first_session) }
          let(:question) { create(:question_single, question_group: question_group) }
          let!(:answer) { create(:answer_single, question: question, user_session: user_session) }

          context 'branches with match' do
            let(:formula) do
              {
                payload: 'test',
                patterns: [{
                  match: '=2',
                  target: [{
                    id: second_session.id,
                    probability: '100',
                    type: 'Session'
                  }]
                },
                           {
                             match: '=1',
                             target: [{
                               id: third_session.id,
                               probability: '100',
                               type: 'Session'
                             }]
                           }]
              }
            end

            it 'returns branched session id' do
              expect(instance.branch_to_session.id).to eq third_session.id
            end
          end

          context 'branches with no match' do
            let(:formula) do
              {
                payload: 'test',
                patterns: [{
                  match: '=2',
                  target: [{
                    id: second_session.id,
                    probability: '100',
                    type: 'Session'
                  }]
                },
                           {
                             match: '=3',
                             target: [{
                               id: third_session.id,
                               probability: '100',
                               type: 'Session'
                             }]
                           }]
              }
            end

            it 'returns branched session id' do
              expect(instance.branch_to_session.id).to eq second_session.id
            end
          end
        end
      end
    end
  end
end
