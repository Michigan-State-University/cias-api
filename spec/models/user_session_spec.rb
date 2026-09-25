# frozen_string_literal: true

require 'rails_helper'
RSpec.describe UserSession, type: :model do
  context 'UserSession' do
    subject { create(:user_session) }

    it { should belong_to(:user) }
    it { should belong_to(:session) }
    it { should have_many(:answers) }
    it { should have_many(:generated_reports) }
    it { should be_valid }
    it { should belong_to(:user_intervention) }

    it 'block to duplicate the record' do
      expect { subject.dup.save! }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  context 'instance methods' do
    context 'user session finish behaviour' do
      let(:intervention) { create(:fixed_order_intervention) }
      let!(:sessions) { create_list(:session, 2, intervention: intervention) }
      let(:user_intervention) { create(:user_intervention, intervention: intervention, status: 'in_progress', completed_sessions: 1) }
      let(:user_session) { create(:user_session, finished_at: finished_at, user_intervention: user_intervention) }
      let(:user_session_schedule_service) { instance_double(V1::UserSessionScheduleService) }
      let(:finished_at) { nil }

      before do
        allow(V1::UserSessionScheduleService).to receive(:new).with(user_session).and_return(user_session_schedule_service)
        ActiveJob::Base.queue_adapter = :test
      end

      context 'user session finish' do
        it 'calls user schedule service correctly' do
          expect(user_session_schedule_service).to receive(:schedule)
          user_session.finish
        end

        it 'does not call user schedule service when send email flag is off' do
          expect(user_session_schedule_service).not_to receive(:schedule)
          user_session.finish(send_email: false)
        end

        it 'update user_session' do
          user_session.finish(send_email: false)
          expect(user_intervention.reload.status).to eq('completed')
          expect(user_intervention.completed_sessions).to eq(2)
          expect(user_intervention.finished_at).not_to be_nil
        end

        context 'user has been finished before' do
          let(:finished_at) { DateTime.now }

          it 'does not call user schedule service' do
            expect(user_session_schedule_service).not_to receive(:schedule)
            user_session.finish
          end
        end

        context 'user session has type CatMh' do
          let(:session) { create(:cat_mh_session, :with_test_type_and_variables, :with_cat_mh_info) }
          let(:user_session) { create(:user_session_cat_mh, session: session, finished_at: finished_at) }

          it 'create answers' do
            expect(user_session_schedule_service).not_to receive(:schedule)
            user_session.finish(send_email: false)
            answers = Answer.where(user_session_id: user_session.id)
            expect(answers.size).to be(2)
            variables = [answers.first.decrypted_body, answers.last.decrypted_body]
            expect(variables).to include(
              { 'data' => [{ 'var' => 'dep_severity', 'value' => 43.9 }] },
              { 'data' => [{ 'var' => 'dep_precision', 'value' => 5.0 }] }
            )
          end
        end

        context 'back button' do
          let!(:answers) { create(:answer_single, user_session: user_session, alternative_branch: true, draft: true) }

          it 'remove all alternative branches' do
            expect { user_session.finish(send_email: false) }.to change(Answer, :count).by(-1)
          end
        end

        context 'when the session is closed by an inactivity timeout' do
          subject(:timeout_finish) { user_session.finish(reason: 'inactivity_timeout') }

          it 'records why the session was closed' do
            expect { timeout_finish }.to change { user_session.reload.finish_reason }.from(nil).to('inactivity_timeout')
          end

          it 'still generates the reports' do
            expect { timeout_finish }.to have_enqueued_job(AfterFinishUserSessionJob)
              .with(user_session.id, user_session.session.intervention, 'inactivity_timeout')
          end

          it 'does not schedule the planned text messages' do
            expect(V1::SmsPlans::ScheduleSmsForUserSession).not_to receive(:call)
            timeout_finish
          end

          it 'does not schedule the next session' do
            expect(user_session_schedule_service).not_to receive(:schedule)
            timeout_finish
          end

          it 'does not feed the organization dashboards' do
            expect(V1::ChartStatistics::CreateForUserSession).not_to receive(:call)
            timeout_finish
          end

          it 'does not count the session as completed' do
            expect { timeout_finish }.not_to change { user_session.user_intervention.reload.completed_sessions }
          end
        end
      end

      context 'user session on answer' do
        let(:user_session) { create(:user_session, timeout_job_id: timeout_job_id, session: create(:session, autofinish_enabled: true)) }
        let(:expected_timestamp) { 24.hours.from_now }
        let(:timeout_job_id) { nil }

        context 'timeout_job_id is nil' do
          it 'schedules session timeout correctly' do
            expect { user_session.on_answer }.to have_enqueued_job(UserSessionTimeoutJob)
                                                   .with(user_session.id, 'completed')
                                                   .at(a_value_within(1.second).of(expected_timestamp))
          end

          it 'does not call #cancel without timout_job_id' do
            expect(UserSessionTimeoutJob).not_to receive(:cancel)
            user_session.on_answer
          end
        end

        context 'when session contains question which run timeout' do
          let(:question_group) { create(:question_group, session: user_session.session) }
          let!(:question) { create(:question_single, :start_autofinish_timer_on, question_group: question_group) }

          context 'when answer does\'t exist for question which trigger timeout' do
            it 'doesn\'t schedule session timeout' do
              expect { user_session.on_answer }.not_to have_enqueued_job(UserSessionTimeoutJob)
            end
          end

          context 'when answer exists for question which trigger timeout' do
            let!(:answer) { create(:answer_single, question: question, user_session: user_session) }

            it 'schedule session timeout' do
              expect { user_session.on_answer }.to have_enqueued_job(UserSessionTimeoutJob)
            end
          end

          context 'when autofinish is disabled' do
            before { user_session.session.update!(autofinish_enabled: false) }

            context 'and the participant has not passed the threshold' do
              it 'does not schedule any timeout' do
                expect { user_session.on_answer }.not_to have_enqueued_job(UserSessionTimeoutJob)
              end
            end

            context 'and the participant has passed the threshold' do
              let!(:answer) { create(:answer_single, question: question, user_session: user_session) }

              before { stub_const('UserSession::ClassicBehavior::INACTIVITY_TIMEOUT_DELAY', 30.minutes) }

              it 'schedules an inactivity timeout after the inactivity delay' do
                expect { user_session.on_answer }
                  .to have_enqueued_job(UserSessionTimeoutJob)
                  .with(user_session.id, 'inactivity_timeout')
                  .at(a_value_within(1.second).of(30.minutes.from_now))
              end

              it 'records when the countdown started' do
                expect { user_session.on_answer }.to change { user_session.reload.last_answer_at }.from(nil)
              end
            end
          end

          context 'when the participant answers a later question after passing the threshold' do
            let!(:plain_question) { create(:question_single, question_group: question_group) }

            before do
              create(:answer_single, question: question, user_session: user_session)
              user_session.on_answer
              # Sidekiq stores the job id on the record in production; the test adapter does not
              user_session.update!(timeout_job_id: 'provider-job-id')
              create(:answer_single, question: plain_question, user_session: user_session)
            end

            it 'keeps the timeout armed' do
              expect { user_session.on_answer }.to have_enqueued_job(UserSessionTimeoutJob)
            end
          end
        end

        context 'when timeout_job_id is set' do
          let(:timeout_job_id) { 'test_timeout_job' }

          it 'triggers #cancel on UserSessionTimeoutJob with timeout_job_id' do
            expect(UserSessionTimeoutJob).to receive(:cancel_by).with({ provider_job_id: timeout_job_id })
            user_session.on_answer
          end
        end

        context 'when timeout is disable' do
          before do
            user_session.session.update!(autofinish_enabled: false)
          end

          it 'doesn\'t schedule session timeout' do
            expect { user_session.on_answer }.not_to have_enqueued_job(UserSessionTimeoutJob)
          end
        end

        context 'when delay is not default' do
          let(:expected_timestamp) { 72.minutes.from_now }

          before do
            user_session.session.update!(autofinish_delay: 72)
          end

          it 'schedules session timeout correctly' do
            expect { user_session.on_answer }.to have_enqueued_job(UserSessionTimeoutJob)
                                                   .with(user_session.id, 'completed')
                                                   .at(a_value_within(1.second).of(expected_timestamp))
          end
        end
      end
    end

    context 'UserSession::CatMh' do
      let(:intervention) { create(:intervention) }
      let(:user_intervention) { create(:user_intervention, intervention: intervention) }
      let(:session) { create(:cat_mh_session, :with_test_type_and_variables, :with_cat_mh_info, intervention: intervention) }
      let(:user_session) { create(:user_session_cat_mh, session: session, user_intervention: user_intervention) }

      it 'have assign needed information' do
        expect(user_session.identifier).not_to be_nil
        expect(user_session.signature).not_to be_nil
        expect(user_session.jsession_id).not_to be_nil
        expect(user_session.awselb).not_to be_nil
      end

      it 'update user_session' do
        user_session.finish(send_email: false)
        expect(user_intervention.status).to eq('completed')
        expect(user_intervention.completed_sessions).to eq(1)
        expect(user_intervention.finished_at).not_to be_nil
      end
    end

    context 'multiple fill sessions' do
      let(:user) { create(:user, :confirmed, :participant) }
      let(:intervention) { create(:intervention) }
      let(:user_intervention) { create(:user_intervention, intervention: intervention, status: :in_progress) }
      let(:session) { create(:session, :multiple_times, intervention: intervention) }
      let(:user_session) { create(:user_session, user_intervention: user_intervention, session: session, user: user, multiple_fill: true) }
      let(:user_session2) { create(:user_session, user_intervention: user_intervention, session: session, user: user, multiple_fill: true) }

      it 'does not change status to completed when having multiple fill sessions' do
        user_session.finish(send_email: false)
        expect(user_intervention.status).to eq('in_progress')
      end

      it 'updates completed_sessions field only once' do
        user_session.finish(send_email: false)
        user_session2.finish(send_email: false)
        expect(user_intervention.reload.completed_sessions).to eq 1
      end
    end

    context 'destroy' do
      let!(:user_session) { create(:user_session) }

      it '#destroy - calls decrement_audio_usage' do
        expect(user_session).to receive(:decrement_audio_usage)
        user_session.destroy
      end

      it '#destroy - calls cancel_timeout_job' do
        expect(user_session).to receive(:cancel_timeout_job)
        user_session.destroy
      end
    end
  end

  context 'validation' do
    let(:intervention) { create(:intervention, organization: organization) }
    let!(:sessions) { create_list(:session, 2, intervention: intervention) }

    context 'when in an user intervention with a health clinic' do
      let(:organization) { create(:organization, :with_health_clinics) }
      let(:health_clinic) { organization.health_clinics.sample }
      let!(:user_intervention) { create(:user_intervention, intervention: intervention, health_clinic_id: health_clinic.id) }
      let!(:user_session) { create(:user_session, user_intervention: user_intervention, health_clinic_id: health_clinic.id) }

      it 'disallows for health_clinic_id to be nil' do
        expect { user_session.update!(health_clinic_id: nil) }.to raise_error(ActiveRecord::RecordInvalid)
      end

      context 'when preview' do
        let(:preview_user) { create(:user, :preview_session) }
        let!(:user_intervention) { create(:user_intervention, user: preview_user, intervention: intervention, health_clinic_id: health_clinic.id) }
        let!(:user_session) { create(:user_session, user: preview_user, user_intervention: user_intervention, health_clinic_id: health_clinic.id) }

        it 'allows for health_clinic_id to be nil' do
          expect(user_session.update!(health_clinic_id: nil)).to be true
        end
      end
    end

    context 'when in an user intervention without a health clinic' do
      let(:organization) { nil }
      let!(:user_intervention) { create(:user_intervention, intervention: intervention) }
      let!(:user_session) { create(:user_session, user_intervention: user_intervention) }

      it 'allows for health_clinic_id to be nil' do
        expect(user_session.update!(health_clinic_id: nil)).to be true
      end
    end
  end
end
