# frozen_string_literal: true

RSpec.describe DuplicateJobs::Session, type: :job do
  include ActiveJob::TestHelper
  subject { described_class.perform_now(user, session.id, new_intervention.id) }

  let!(:user) { create(:user, :confirmed, :researcher) }
  let!(:intervention) { create(:intervention, user: user, status: 'published') }
  let!(:new_intervention) { create(:intervention, user: user, status: 'published') }
  let!(:other_session) { create(:session, intervention: intervention) }
  let!(:session) do
    create(:session, intervention: intervention, name: 'Test', formulas: [{ 'payload' => 'var + 5', 'patterns' => [
             { 'match' => '=8', 'target' => [{ 'id' => other_session.id, 'probability' => '100', type: 'Session' }] }
           ] }])
  end
  let!(:clone_params) { {} }

  before do
    ActiveJob::Base.queue_adapter = :test
    allow(Intervention).to receive(:clone)
  end

  after do
    subject
  end

  context 'email notifications enabled' do
    it 'send email' do
      expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
    end
  end

  context 'email notifications disabled' do
    let!(:user) { create(:user, :confirmed, :researcher, email_notification: false) }

    it "Don't send email" do
      expect { subject }.not_to change { ActionMailer::Base.deliveries.size }
    end
  end

  context 'assign a new session to the intervention' do
    before do
      subject
    end

    it 'add new session to intervention' do
      expect(new_intervention.reload.sessions.count).to be(1)
      expect(new_intervention.sessions.last.name).to eql(session.name)
      expect(new_intervention.sessions.last.schedule).to eql(session.schedule)
      expect(new_intervention.sessions.last.schedule_payload).to eql(session.schedule_payload)
      expect(new_intervention.sessions.last.variable).to eql("duplicated_#{session.variable}_#{new_intervention.sessions.last&.position.to_i}")
    end

    it 'have correct question group' do
      expect(new_intervention.sessions.last.question_groups.first).not_to be_nil
      expect(new_intervention.sessions.last.question_groups.first.title).to eq(session.question_groups.first.title)
    end

    it 'clear formula' do
      expect(new_intervention.reload.sessions.first.formulas[0]).to include(
        'payload' => '',
        'patterns' => []
      )
    end

    it 'clears the days_after_variable_name value' do
      expect(new_intervention.reload.sessions.first['days_after_date_variable_name']).to be_nil
    end
  end

  context 'when new intervention does\'t exist' do
    subject { described_class.perform_now(user, session.id, 'wrong_id') }

    it 'did\'t create a new session' do
      expect { subject }.to avoid_changing(Session, :count)
    end
  end

  context 'when the session does\'t exist' do
    subject { described_class.perform_now(user, 'wrong_id', new_intervention.id) }

    it 'did\'t create a new session' do
      expect { subject }.to avoid_changing(Session, :count)
    end
  end

  context 'when copying to the intervention without hf access' do
    let!(:intervention) { create(:intervention, user: user, status: 'published', hfhs_access: true) }
    let!(:question_group) { create(:question_group, session: session) }
    let!(:hf_initial_screen) { create(:question_henry_ford_initial_screen, question_group: question_group) }
    let!(:question_single) { create(:question_single, question_group: question_group) }
    let(:cloned_questions) { new_intervention.sessions.last.question_groups.first.questions.map(&:type) }

    before do
      subject
    end

    it 'do not duplicate hf initial screen' do
      expect(cloned_questions).to eq(['Question::Single'])
    end
  end

  context 'when duplicating session with reflection' do
    subject { described_class.perform_now(user, session2.id, new_intervention.id) }

    let!(:session1) { create(:session, intervention: intervention, position: 1) }
    let!(:session2) { create(:session, intervention: intervention, position: 2) }
    let!(:question_group1) { create(:question_group, title: 'Question Group Title 1', session: session1, position: 1) }
    let!(:question_group2) { create(:question_group, title: 'Question Group Title 2', session: session2, position: 1) }
    let!(:session1_question) do
      create(
        :question_single,
        question_group: question_group1,
        subtitle: 'Question Subtitle',
        position: 1,
        body: {
          data: [{ payload: 'a1', value: '1' }, { payload: 'a2', value: '2' }],
          variable: { name: 'var' }
        }
      )
    end
    let!(:session2_question) do
      create(:question_single, question_group: question_group2, subtitle: 'Question Subtitle 2', position: 1,
                               narrator: {
                                 blocks: [
                                   {
                                     action: 'NO_ACTION',
                                     question_id: session1_question.id,
                                     reflections: [
                                       {
                                         text: ['Test1'],
                                         value: '1',
                                         type: 'Speech',
                                         sha256: ['80fc22b48738e42f920aca2c00b189ae565a268c45334e4cb5d056bede799cd2'],
                                         payload: 'a1',
                                         variable: 'var',
                                         audio_urls: ['spec/factories/audio/80fc22b48738e42f920aca2c00b189ae565a268c45334e4cb5d056bede799cd2.mp3']
                                       },
                                       {
                                         text: ['Test2'],
                                         value: '2',
                                         type: 'Speech',
                                         sha256: ['80fc22b48738e42f920aca2c00b189ae565a268c45334e4cb5d056bede799cd2'],
                                         payload: 'a2',
                                         variable: 'var',
                                         audio_urls: ['spec/factories/audio/80fc22b48738e42f920aca2c00b189ae565a268c45334e4cb5d056bede799cd2.mp3']
                                       }
                                     ],
                                     animation: 'pointUp',
                                     type: 'Reflection',
                                     endPosition: {
                                       x: 0,
                                       y: 600
                                     }
                                   }
                                 ],
                                 settings: default_narrator_settings
                               })
    end
    let(:default_narrator_settings) do
      {
        'voice' => true,
        'animation' => true,
        'character' => 'peedy'
      }
    end

    before do
      subject
    end

    it 'adds new session to intervention' do
      expect(new_intervention.reload.sessions.count).to be(1)
    end

    it 'removes reflection from cloned sessions question' do
      expect(new_intervention.reload.sessions.last.questions.first.narrator['blocks']).to eq([])
    end
  end
end
