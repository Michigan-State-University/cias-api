# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Intervention, type: :model do
  context 'Intervention' do
    subject { create(:intervention) }

    let(:initial_status) { subject }

    it { should belong_to(:user) }
    it { should belong_to(:current_editor).optional }
    it { should have_many(:sessions) }
    it { should have_many(:user_interventions) }
    it { should have_many(:conversations) }
    it { should have_many(:notifications) }
    it { should have_many(:collaborators) }
    it { should belong_to(:google_language).optional }
    it { should be_valid }
    it { should have_many(:short_links).dependent(:destroy) }
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

  context 'clone' do
    let(:user) { create(:user, :confirmed, :researcher) }
    let(:intervention) { create(:intervention, :with_short_link) }
    let!(:session) { create(:session, intervention: intervention, position: 1) }
    let!(:other_session) do
      create(:session, intervention: intervention, position: 2,
                       formulas: [{ 'payload' => 'var + 2',
                                    'patterns' =>
                          [{ 'match' => '=1',
                             'target' =>
                               [{ 'id' => third_session.id, 'type' => 'Session' }] }] }])
    end
    let!(:third_session) do
      create(:session, intervention: intervention, position: 3,
                       formulas: [{ 'payload' => '',
                                    'patterns' =>
                          [{ 'match' => '',
                             'target' =>
                               [{ 'id' => '', 'type' => 'Session' }] }] }])
    end
    let!(:question_group) { create(:question_group, title: 'Question Group Title', session: session) }
    let!(:question1) do
      create(:question_single, question_group: question_group, subtitle: 'Question Subtitle', position: 1,
                               formulas: [{ 'payload' => 'var + 3', 'patterns' => [
                                 { 'match' => '=7', 'target' => [{ 'id' => question2.id, type: 'Question::Single' }] }
                               ] }])
    end
    let!(:question2) do
      create(:question_single, question_group: question_group, subtitle: 'Question Subtitle 2', position: 2,
                               formulas: [{ 'payload' => 'var + 4', 'patterns' => [
                                 { 'match' => '=3', 'target' => [{ 'id' => other_session.id, type: 'Session' }] }
                               ] }])
    end

    it 'return correct data' do
      cloned_intervention = intervention.clone

      expect(intervention.attributes.except('id', 'created_at', 'updated_at', 'status',
                                            'name')).to eq(cloned_intervention.attributes.except('id', 'created_at', 'updated_at', 'status', 'name'))
      expect(cloned_intervention.status).to eq('draft')
      expect(cloned_intervention.name).to include('Copy of')
    end

    it 'remove short links' do
      cloned_intervention = intervention.clone
      expect(cloned_intervention.short_links.any?).to be false
    end

    it 'correct clone questions to cloned session' do
      cloned_intervention = intervention.clone
      cloned_sessions = cloned_intervention.sessions.order(:position)
      cloned_questions = cloned_sessions.first.questions.order(:position)
      expect(cloned_questions.map(&:attributes)).to include(
        include(
          'subtitle' => 'Question Subtitle',
          'position' => 1,
          'body' => include(
            'variable' => { 'name' => 'single_var' }
          ),
          'formulas' => [{
            'payload' => 'var + 3',
            'patterns' => [
              { 'match' => '=7', 'target' => [{ 'id' => cloned_questions.second.id, 'type' => 'Question::Single' }] }
            ]
          }]
        ),
        include(
          'subtitle' => 'Question Subtitle 2',
          'position' => 2,
          'body' => include(
            'variable' => { 'name' => 'single_var' }
          ),
          'formulas' => [{
            'payload' => 'var + 4',
            'patterns' => [
              { 'match' => '=3', 'target' => [{ 'id' => cloned_sessions.second.id, 'type' => 'Session' }] }
            ]
          }]
        ),
        include(
          'position' => 999_999,
          'type' => 'Question::Finish'
        )
      )
    end

    it 'correctly clones sessions with proper connections between other sessions' do
      cloned_intervention = intervention.clone
      cloned_sessions = cloned_intervention.sessions.order(:position)
      second_cloned_session = cloned_sessions.second
      third_cloned_session = cloned_sessions.third

      expect(second_cloned_session.attributes).to include(
        'position' => 2,
        'formulas' => [{
          'payload' => 'var + 2',
          'patterns' => [
            { 'match' => '=1', 'target' => [{ 'id' => third_cloned_session.id, 'type' => 'Session' }] }
          ]
        }]
      )
      expect(third_cloned_session.attributes).to include(
        'position' => 3,
        'formulas' => [{
          'payload' => '',
          'patterns' => [
            { 'match' => '', 'target' => [{ 'id' => '', 'type' => 'Session' }] }
          ]
        }],
        'variable' => third_session.variable.to_s
      )
    end

    context 'when researcher want to assign the intervention to other resarcher' do
      let(:other_user) { create(:user, :confirmed, :researcher) }
      let(:params) { { emails: [other_user.email.upcase] } }

      it 'create a new intervention with correct user_id' do
        cloned_intervention = intervention.clone(params: params)

        expect(cloned_intervention.first.user_id).to eq(other_user.id)
      end
    end
  end
end
