# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Session, type: :model do
  describe 'Session' do
    subject { build(:session, variable: variable, intervention: intervention) }

    let(:variable) { 'session_1' }
    let(:intervention) { create(:intervention) }

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
        let(:schedule_at) { DateTime.now.tomorrow }
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

        context 'session schedule is days after date' do
          let(:participant) { create(:user, :confirmed, :participant) }
          let!(:user_session) { create(:user_session, user: participant, session_id: session.id) }
          let!(:update_session) { session.days_after_date_variable_name = 'var1' }
          let!(:answer) { create(:answer_date, user_session: user_session, body: { data: [{ var: 'var1', value: DateTime.now.tomorrow }] }) }
          let!(:all_var_values) { user_session.all_var_values(include_session_var: false) }
          let!(:calculated_date) do
            all_var_values[session.days_after_date_variable_name].to_datetime + session.schedule_payload&.days
          end

          let(:schedule) { 'days_after_date' }

          it 'returns false' do
            expect(session.available_now(calculated_date)).to be(false)
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

                context 'email notification enabled' do
                  it 'schedules send email' do
                    expect(SessionMailer).to receive(:inform_to_an_email).with(session, user.email, nil).and_return(
                      message_delivery
                    )
                  end
                end

                context 'email notification disabled' do
                  let!(:disable_email_notification) { user.email_notification = false }

                  it "Don't schedule send email" do
                    expect(SessionMailer).not_to receive(:inform_to_an_email)
                  end
                end
              end
            end
          end
        end
      end

      describe '#session_variables' do
        let!(:session) { create(:session) }
        let!(:question_group) { create(:question_group, session: session) }
        let!(:question) { create(:question_single, :branching_to_session, question_group: question_group) }

        it 'returns correct session variables' do
          expect(session.session_variables).to eq ['a1']
        end
      end

      describe '#translate' do
        let!(:session) { create(:session, :with_sms_plans, :with_report_templates) }
        let(:translator) { V1::Google::TranslationService.new }
        let(:source_language_name_short) { 'en' }
        let(:destination_language_name_short) { 'pl' }
        let(:first_report_template) { session.reload.report_templates.first }
        let(:variant) { first_report_template.variants.first }
        let(:first_sms_plan) { session.reload.sms_plans.first }

        before do
          session.translate(translator, source_language_name_short, destination_language_name_short)
        end

        it 'translate questions' do
          expect(session.reload.questions.first.title).to include(
            {
              'from' => source_language_name_short,
              'to' => destination_language_name_short,
              'text' => 'Enter title here'
            }.to_s
          )
          expect(session.reload.questions.first.subtitle).to include(
            {
              'from' => source_language_name_short,
              'to' => destination_language_name_short,
              'text' => '<h2>Enter main text for screen here </h2><br><i>Note: this is the last screen participants will see in this session</i>'
            }.to_s
          )
          expect(session.reload.questions.first.narrator['blocks'].first['text']).to include(
            {
              'to' => 'pl',
              'from' => 'en',
              'text' => 'Enter main text for screen here. This is the last screen participants will see in this session'
            }
          )
        end

        it 'translate reports' do
          expect(first_report_template.summary).to include('"from"=>"en", "to"=>"pl"')
          expect(first_report_template.name).to include('"from"=>"en", "to"=>"pl"')
          expect(variant.title).to include('"from"=>"en", "to"=>"pl"')
          expect(variant.content).to include('"from"=>"en", "to"=>"pl"')
        end

        it 'translate sms plans' do
          expect(first_sms_plan.no_formula_text).to include('"from"=>"en", "to"=>"pl"')
        end
      end
    end

    context 'validations' do
      context 'unique_variable' do
        context 'when variable exists in other session of the same intervention' do
          let!(:session_2) { create(:session, variable: variable, intervention: intervention) }

          it 'invalidate' do
            expect(subject.validate).to eq false
          end
        end

        context 'when variable exists in other session, but in other intervention' do
          let!(:session_2) { create(:session, variable: variable) }

          it 'validate' do
            expect(subject.validate).to eq true
          end
        end

        context "when variable doesn't exist in other sessions" do
          it 'validate' do
            expect(subject.validate).to eq true
          end
        end
      end
    end
  end
end
