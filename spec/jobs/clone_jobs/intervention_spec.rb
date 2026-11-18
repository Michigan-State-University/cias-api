# frozen_string_literal: true

RSpec.describe CloneJobs::Intervention, type: :job do
  subject { described_class.perform_now(user, intervention.id, clone_params) }

  let!(:user) { create(:user, :confirmed, :researcher) }
  let!(:intervention) { create(:intervention, user: user, status: 'published') }
  let!(:clone_params) { {} }

  let(:message_delivery) { instance_double(ActionMailer::MessageDelivery) }

  before do
    allow(message_delivery).to receive(:deliver_now)
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

  context 'share intervention' do
    let(:researcher1) { create(:user, :confirmed, :researcher) }
    let(:researcher2) { create(:user, :confirmed, :researcher) }
    let!(:clone_params) do
      { emails: [
        researcher1.email,
        researcher2.email
      ] }
    end

    it 'send email' do
      expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(2)
    end
  end

  context 'Session::CatMh' do
    let(:intervention) do
      create(:intervention, name: 'CAT-MH', cat_mh_application_id: 'application_id', cat_mh_organization_id: 'organization_id', cat_mh_pool: 100)
    end
    let!(:session) { create(:session, intervention: intervention, position: 1) }

    it 'create a new cloned' do
      expect { subject }.to change(Intervention, :count).by(1)
    end

    it 'clear cat mh settings' do
      subject
      expect(Intervention.order(:created_at).last.attributes.slice('cat_mh_application_id', 'cat_mh_organization_id', 'cat_mh_pool',
                                                                   'created_cat_mh_session_count')).to eq(
                                                                     {
                                                                       'cat_mh_application_id' => nil,
                                                                       'cat_mh_organization_id' => nil,
                                                                       'cat_mh_pool' => nil,
                                                                       'created_cat_mh_session_count' => 0
                                                                     }
                                                                   )
    end
  end

  context 'Intervention with HFH access' do
    let!(:intervention) { create(:intervention, user: user, status: 'published', hfhs_access: true) }

    it 'does not copy over the HFH access setting' do
      subject
      expect(Intervention.order(:created_at).last.attributes['hfhs_access']).not_to be true
    end
  end

  context 'when the invited reseacher has an activated account' do
    let!(:clone_params) { { email: [user.email] } }

    before { allow(CloneMailer).to receive(:cloned_intervention_activate).and_return(message_delivery) }

    it 'does not create a new user account' do
      expect { subject }.not_to change(User, :count)
    end

    it 'sends a proper email to the user' do
      expect(CloneMailer).to receive(:cloned_intervention)
                              .with(user, intervention.name,
                                    /^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$/)
      subject
    end
  end

  context 'when the invited researcher has an account that\'s not been activated' do
    let!(:new_researcher) { create(:user, :researcher, :unconfirmed) }
    let!(:clone_params) { { emails: [new_researcher.email] } }

    before { allow(CloneMailer).to receive(:cloned_intervention_activate).and_return(message_delivery) }

    it 'does not create a new user account' do
      expect { subject }.not_to change(User, :count)
    end

    it 'sends a proper email to the user' do
      expect(CloneMailer).to receive(:cloned_intervention_activate)
                              .with(new_researcher, intervention.name,
                                    /^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$/)

      subject
    end
  end

  context 'when the invited researcher doesn\'t have an account' do
    let!(:clone_params) { { emails: [Faker::Internet.unique.email] } }

    before { allow(CloneMailer).to receive(:cloned_intervention_activate).and_return(message_delivery) }

    it 'creates a new researcher account' do
      expect { subject }.to change(User, :count).by(1)
    end

    it 'sends a proper email to the researcher' do
      expect(CloneMailer).to receive(:cloned_intervention_activate)
                              .with(instance_of(User), intervention.name,
                                    /^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$/)
      subject
    end
  end

  context 'with cross-session reflections (CIAS-4195)' do
    # Exercise the real clone path instead of the stubbed Intervention.clone.
    before { allow(Intervention).to receive(:clone).and_call_original }

    let!(:intervention) { create(:intervention, user: user, status: 'published') }
    let!(:early_session) { create(:session, intervention: intervention, position: 1) }
    let!(:late_session)  { create(:session, intervention: intervention, position: 2) }
    let!(:early_group) { create(:question_group, session: early_session, position: 1) }
    let!(:late_group)  { create(:question_group, session: late_session, position: 1) }

    let(:narrator_settings) { { 'voice' => true, 'animation' => true, 'character' => 'peedy' } }

    def reflection_block(target_question, target_session)
      {
        action: 'NO_ACTION',
        type: 'Reflection',
        question_id: target_question.id,
        question_group_id: target_question.question_group_id,
        session_id: target_session.id,
        reflections: [],
        animation: 'pointUp'
      }
    end

    def cloned_intervention
      Intervention.where.not(id: intervention.id).order(:created_at).last
    end

    context 'forward reference (reflection in earlier session targets a later session)' do
      let!(:target_question) { create(:question_single, question_group: late_group, position: 1) }
      let!(:reflecting_question) do
        create(:question_single, question_group: early_group, position: 1,
                                 narrator: { blocks: [reflection_block(target_question, late_session)], settings: narrator_settings })
      end

      it 'produces a complete copy (does not crash)' do
        expect { subject }.to change(Intervention, :count).by(1)
      end

      it 'remaps the reflection to the cloned target question' do
        subject
        clone = cloned_intervention
        cloned_target = clone.sessions.find_by(position: 2).questions.find_by(position: 1)
        block = clone.sessions.find_by(position: 1).questions.find_by(position: 1).narrator['blocks'].first

        expect(block['question_id']).to eq(cloned_target.id)
        expect(block['question_group_id']).to eq(cloned_target.question_group_id)
        expect(block['session_id']).to eq(clone.sessions.find_by(position: 2).id)
      end
    end

    context 'backward reference (reflection in later session targets an earlier session)' do
      let!(:target_question) { create(:question_single, question_group: early_group, position: 1) }
      let!(:reflecting_question) do
        create(:question_single, question_group: late_group, position: 1,
                                 narrator: { blocks: [reflection_block(target_question, early_session)], settings: narrator_settings })
      end

      it 'remaps the reflection to the cloned target question' do
        subject
        clone = cloned_intervention
        cloned_target = clone.sessions.find_by(position: 1).questions.find_by(position: 1)
        block = clone.sessions.find_by(position: 2).questions.find_by(position: 1).narrator['blocks'].first

        expect(block['question_id']).to eq(cloned_target.id)
        expect(block['session_id']).to eq(clone.sessions.find_by(position: 1).id)
      end
    end

    context 'mutual references (S1 -> S2 and S2 -> S1)' do
      let!(:early_question) { create(:question_single, question_group: early_group, position: 1) }
      let!(:late_question)  { create(:question_single, question_group: late_group, position: 1) }

      before do
        early_question.update!(narrator: { blocks: [reflection_block(late_question, late_session)], settings: narrator_settings })
        late_question.update!(narrator: { blocks: [reflection_block(early_question, early_session)], settings: narrator_settings })
      end

      it 'remaps both reflections to their cloned targets' do
        subject
        clone = cloned_intervention
        cloned_early = clone.sessions.find_by(position: 1).questions.find_by(position: 1)
        cloned_late  = clone.sessions.find_by(position: 2).questions.find_by(position: 1)

        expect(cloned_early.narrator['blocks'].first['question_id']).to eq(cloned_late.id)
        expect(cloned_late.narrator['blocks'].first['question_id']).to eq(cloned_early.id)
      end
    end

    context 'dangling reference (targets a question/session not present in the source)' do
      let!(:reflecting_question) do
        create(:question_single, question_group: early_group, position: 1,
                                 narrator: { blocks: [{ action: 'NO_ACTION', type: 'Reflection', question_id: SecureRandom.uuid,
                                                        question_group_id: SecureRandom.uuid, session_id: SecureRandom.uuid, reflections: [] }],
                                             settings: narrator_settings })
      end

      it 'produces a copy and neutralizes the unresolvable reflection instead of crashing' do
        expect { subject }.to change(Intervention, :count).by(1)
        blocks = cloned_intervention.sessions.find_by(position: 1).questions.find_by(position: 1).narrator['blocks']
        reflection = blocks.find { |block| block['type'] == 'Reflection' }
        expect(reflection['question_id']).to eq('')
      end
    end
  end

  context 'when cloning raises' do
    before do
      allow(Intervention).to receive(:find).with(intervention.id).and_return(intervention)
      allow(intervention).to receive(:clone).and_raise(StandardError.new('boom'))
      allow(Sentry).to receive(:capture_exception)
      allow(CloneMailer).to receive(:error).and_return(message_delivery)
    end

    it 'reports the failure to Sentry with context' do
      subject
      expect(Sentry).to have_received(:capture_exception)
        .with(instance_of(StandardError), extra: hash_including(user_id: user.id, intervention_id: intervention.id))
    end

    it 'sends the error email' do
      subject
      expect(CloneMailer).to have_received(:error).with(user)
    end
  end
end
