# frozen_string_literal: true

RSpec.describe V1::UserSessionScheduleService do
  let!(:intervention) { create(:intervention, :published) }
  let!(:user) { create(:user, :participant) }
  let!(:preview_user) { create(:user, :preview_session) }
  let!(:first_session) { create(:session, intervention: intervention, position: 1, settings: settings, formulas: [formula]) }
  let!(:second_session) do
    create(:session, intervention: intervention, schedule: schedule, schedule_payload: schedule_payload, position: 2, schedule_at: schedule_at)
  end
  let!(:user_intervention) { create(:user_intervention, intervention: intervention) }
  let!(:third_session) { create(:session, intervention: intervention, position: 3) }
  let!(:organization) { create(:organization, :with_organization_admin, :with_e_intervention_admin, name: 'Health Organization') }
  let!(:health_system) { create(:health_system, :with_health_system_admin, name: 'Heath System', organization: organization) }
  let!(:health_clinic) { create(:health_clinic, :with_health_clinic_admin, name: 'Health Clinic', health_system: health_system) }
  let!(:user_session_not_belongs_to_organization) { create(:user_session, user: user, session: first_session, user_intervention: user_intervention) }
  let!(:user_session_belongs_to_organization) do
    create(:user_session, user: user, session: first_session, health_clinic: health_clinic, user_intervention: user_intervention)
  end
  let!(:user_sessions) do
    {
      'user_session_not_belongs_to_organization' => user_session_not_belongs_to_organization,
      'user_session_belongs_to_organization' => user_session_belongs_to_organization
    }
  end
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

  context 'when user is preview_session' do
    let!(:user_session_not_belongs_to_organization) { create(:user_session, user: preview_user, session: first_session, user_intervention: user_intervention) }
    let!(:user_session_belongs_to_organization) do
      create(:user_session, user: preview_user, session: first_session, health_clinic: health_clinic, user_intervention: user_intervention)
    end
    let!(:user_sessions) do
      {
        'user_session_not_belongs_to_organization' => user_session_not_belongs_to_organization,
        'user_session_belongs_to_organization' => user_session_belongs_to_organization
      }
    end

    context 'check behavior to user session belongs and doesn\'t belongs to organization ' do
      %w[user_session_not_belongs_to_organization user_session_belongs_to_organization].each do |specific_user_session|
        let(:user_session) { user_sessions[specific_user_session] }

        context 'when session has schedule after fill' do
          after { described_class.new(user_session).schedule }

          it 'does not send an email' do
            expect(SessionMailer).not_to receive(:inform_to_an_email).with(second_session, preview_user.email, user_session.health_clinic)
          end
        end

        context 'when scheduling uses schedule_at which is nil' do
          let(:schedule_at) { nil }

          %w[exact_date days_after].each do |schedule_type|
            context "when session has schedule #{schedule_type}" do
              it 'does not schedule at all' do
                expect { described_class.new(user_session).schedule }.not_to have_enqueued_job(SessionScheduleJob)
              end
            end
          end
        end

        context 'when scheduling into the past' do
          let!(:schedule) { 'exact_date' }
          let!(:schedule_payload) { nil }
          let!(:schedule_at) { 7.days.ago }

          it "doesn't run the job" do
            expect { described_class.new(user_session).schedule }.not_to have_enqueued_job(SessionScheduleJob)
          end

          it "sets the next user session's scheduled at to a past date" do
            described_class.new(user_session).tap do |service|
              service.schedule
              expect(service.next_user_session.reload.scheduled_at.past?).to eq(true)
            end
          end
        end
      end
    end
  end

  context 'check behavior to user session belongs and doesn\'t belongs to organization ' do
    %w[user_session_not_belongs_to_organization user_session_belongs_to_organization].each do |specific_user_session|
      let(:user_session) { user_sessions[specific_user_session] }
      context 'user session schedule service' do
        context 'session scheduling' do
          context 'when session has schedule after fill' do
            after { described_class.new(user_session).schedule }

            it 'calls correct method' do
              expect_any_instance_of(described_class).to receive(:after_fill_schedule)
            end

            it 'sends an email' do
              expect(SessionMailer).to receive(:inform_to_an_email).with(second_session, user.email, user_session.health_clinic).and_return(message_delivery)
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
              expect { described_class.new(user_session).schedule }.to have_enqueued_job(SessionScheduleJob)
                                                                         .with(second_session.id, user.id, user_session.health_clinic, user_intervention.id)
                                                                         .at(a_value_within(1.second).of(expected_timestamp))
            end

            it 'crate next user_session' do
              expect { described_class.new(user_session).schedule }.to change(UserSession, :count).by(1)
            end
          end

          context 'when session has schedule exact date' do
            let(:schedule) { 'exact_date' }

            it 'calls correct method' do
              expect_any_instance_of(described_class).to receive(:exact_date_schedule)
              described_class.new(user_session).schedule
            end

            it 'schedules on correct time' do
              expect { described_class.new(user_session).schedule }.to have_enqueued_job(SessionScheduleJob)
                                                                         .with(second_session.id, user.id, user_session.health_clinic, user_intervention.id)
                                                                         .at(a_value_within(1.second).of(Date.parse(schedule_at).noon))
            end

            it 'crate next user_session' do
              expect { described_class.new(user_session).schedule }.to change(UserSession, :count).by(1)
            end
          end

          context 'when session has schedule days_after' do
            let(:schedule) { 'days_after' }

            it 'calls correct method' do
              expect_any_instance_of(described_class).to receive(:days_after_schedule)
              described_class.new(user_session).schedule
            end

            it 'schedules on correct time' do
              expect { described_class.new(user_session).schedule }.to have_enqueued_job(SessionScheduleJob)
                                                                         .with(second_session.id, user.id, user_session.health_clinic, user_intervention.id)
                                                                         .at(a_value_within(1.second).of(Date.parse(schedule_at).noon))
            end

            it 'crate next user_session' do
              expect { described_class.new(user_session).schedule }.to change(UserSession, :count).by(1)
            end
          end

          context 'when session has schedule days_after_date' do
            let(:schedule) { 'days_after_date' }
            let(:tomorrow) { DateTime.now.tomorrow }

            context 'when days_after_date_variable is given' do
              let!(:update_second_session) { second_session.update(days_after_date_variable_name: "#{user_session.session.variable}.days_after_date_variable") }
              let!(:answer) do
                create(:answer_date, user_session: user_session,
                                     body: { data: [{ var: 'days_after_date_variable', value: tomorrow.to_s }] })
              end

              it 'calls correct method' do
                expect_any_instance_of(described_class).to receive(:days_after_date_schedule)
                described_class.new(user_session).schedule
              end

              it 'schedules on correct time' do
                expect { described_class.new(user_session).schedule }.to have_enqueued_job(SessionScheduleJob)
                                                                           .with(second_session.id, user.id, user_session.health_clinic, user_intervention.id)
                                                                           .at(a_value_within(1.second).of((tomorrow + schedule_payload.days).noon))
              end

              it 'crate next user_session' do
                expect { described_class.new(user_session).schedule }.to change(UserSession, :count).by(1)
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
  end

  context 'when user is guest' do
    let!(:user) { create(:user, :guest) }

    it 'crate next user_session' do
      expect { described_class.new(user_session_not_belongs_to_organization).schedule }.not_to change(UserSession, :count)
    end
  end
end
