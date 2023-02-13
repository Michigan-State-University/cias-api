# frozen_string_literal: true

RSpec.describe MultipleCharacters::ChangeNarratorJob, type: :job do
  subject { described_class.perform_now(user_email, model, object_id, new_character, new_animations) }

  let(:user_email) { create(:user, :confirmed, :researcher).email }
  let(:new_character) { 'emmi' }
  let(:new_animations) do
    {
      'HeadAnimation' => { 'eatCracker' => 'acknowledge' },
      'Pause' => { 'standStill' => 'restWeightShift' }
    }
  end

  describe 'intervention' do
    let(:model) { Intervention.name }
    let(:object_id) { create(:intervention).id }

    before do
      ActiveJob::Base.queue_adapter = :test
      allow(V1::MultipleCharacters::Interventions::ChangeService).to receive(:call).with(object_id, new_character, new_animations).and_return(true)
    end

    it 'call correct service' do
      subject
      expect(V1::MultipleCharacters::Interventions::ChangeService).to have_received(:call)
    end
  end

  describe 'session' do
    let(:model) { Session.name }
    let(:object_id) { create(:session).id }

    before do
      ActiveJob::Base.queue_adapter = :test
      allow(V1::MultipleCharacters::Sessions::ChangeService).to receive(:call).with(object_id, new_character, new_animations).and_return(true)
    end

    it 'call correct service' do
      subject
      expect(V1::MultipleCharacters::Sessions::ChangeService).to have_received(:call)
    end
  end
end
