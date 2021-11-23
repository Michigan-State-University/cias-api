# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Intervention, type: :model do
  context 'Intervention' do
    subject { create(:intervention) }

    let(:initial_status) { subject }

    it { should belong_to(:user) }
    it { should have_many(:sessions) }
    it { should have_many(:user_interventions) }
    it { should belong_to(:google_language).optional }
    it { should be_valid }
    it { expect(initial_status.draft?).to be true }
  end

  describe 'instance methods' do
    describe 'translation' do
      let(:intervention) { create(:intervention_with_logo, name: 'New intervention') }
      let(:translator) { V1::Google::TranslationService.new }
      let(:source_language_name_short) { 'en' }
      let(:destination_language_name_short) { 'pl' }

      before do
        intervention.logo_blob.description = 'This is the description'
        intervention.translate(translator, source_language_name_short, destination_language_name_short)
      end

      describe '#translation_prefix' do
        it 'add correct prefix' do
          expect(intervention.reload.name).to include("(#{destination_language_name_short.upcase}) New intervention")
        end
      end
    end

    describe '#invite_by_email' do
      before do
        allow(message_delivery).to receive(:deliver_later)
        ActiveJob::Base.queue_adapter = :test
      end

      after { intervention.invite_by_email([user.email]) }

      let(:message_delivery) { instance_double(ActionMailer::MessageDelivery) }
      let(:intervention) { create(:intervention, status: status) }
      let(:status) { :draft }
      let(:user) { create(:user, :confirmed, :admin) }

      context 'intervention is draft' do
        it 'dose not schedule send email' do
          expect(InterventionMailer).not_to receive(:inform_to_an_email)
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
                allow(InterventionMailer).to receive(:inform_to_an_email).with(intervention, user.email, nil).and_return(
                  message_delivery
                )
              end
            end

            context 'email notification disabled' do
              let!(:disable_email_notification) { user.email_notification = false }

              it "Don't schedule send email" do
                expect(InterventionMailer).not_to receive(:inform_to_an_email)
              end
            end
          end
        end
      end
    end
  end
end
