# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Session, type: :model do
  describe 'Session' do
    subject { create(:session) }

    it { should belong_to(:intervention) }
    it { should have_many(:question_groups) }
    it { should have_many(:questions) }
    it { should have_many(:report_templates).dependent(:destroy) }
    it { should have_many(:sms_plans).dependent(:destroy) }

    it { should be_valid }

    describe 'instance methods' do
      describe '#create with question groups' do
        let(:new_session) { build(:session) }

        it 'creates new default question group' do
          expect { new_session.save! }.to change(QuestionGroup, :count).by(1)
          expect(new_session.reload.question_group_plains.model_name.name).to eq 'QuestionGroup::Plain'
          expect(new_session.reload.question_group_finish.model_name.name).to eq 'QuestionGroup::Finish'
          expect(new_session.reload.question_groups.size).to eq 1
        end
      end

      describe '#available_now' do
        let(:session) { create(:session, schedule: schedule, schedule_at: schedule_at, schedule_payload: schedule_payload) }
        let(:schedule) { 'after_fill' }
        let(:schedule_at) { DateTime.now + 1.day }
        let(:schedule_payload) { 2 }

        context 'session schedule is after fill' do
          it 'returns true' do
            expect(session.available_now).to be(true)
          end
        end

        context 'session schedule is days after fill' do
          let(:schedule) { 'days_after_fill' }

          it 'returns false' do
            expect(session.available_now).to be(false)
          end
        end

        context 'session schedule' do
          let(:schedule) { 'exact_date' }

          context 'session is in the feature' do
            it 'returns false ' do
              expect(session.available_now).to be(false)
            end
          end

          context 'session is in the past' do
            let(:schedule_at) { DateTime.now - 1.day }

            it 'returns true' do
              expect(session.available_now).to be(true)
            end
          end
        end
      end

      describe '#send_link_to_session' do
        before do
          allow(message_delivery).to receive(:deliver_later)
          ActiveJob::Base.queue_adapter = :test
        end

        after { session.send_link_to_session(user) }

        let(:message_delivery) { instance_double(ActionMailer::MessageDelivery) }
        let(:intervention) { create(:intervention, status: status) }
        let(:session) { create(:session, intervention: intervention) }
        let(:status) { :draft }

        context 'intervention is draft' do
          %i[admin researcher participant guest preview_session].each do |role|
            context "user is #{role}" do
              let(:user) { create(:user, :confirmed, role) }

              it 'dose not schedule send email' do
                expect(SessionMailer).not_to receive(:inform_to_an_email)
              end
            end
          end

          context 'intervention is published' do
            let(:status) { :published }

            %i[guest preview_session].each do |role|
              context "user is #{role}" do
                let(:user) { create(:user, :confirmed, role) }

                it 'dose not schedule send email' do
                  expect(SessionMailer).not_to receive(:inform_to_an_email)
                end
              end
            end

            %i[admin researcher participant].each do |role|
              context "user is #{role}" do
                let(:user) { create(:user, :confirmed, role) }

                it 'schedules send email' do
                  expect(SessionMailer).to receive(:inform_to_an_email).with(session, user.email).and_return(message_delivery)
                end
              end
            end
          end
        end
      end
    end
  end
end
