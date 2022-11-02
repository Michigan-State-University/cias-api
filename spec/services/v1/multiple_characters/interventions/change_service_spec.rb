# frozen_string_literal: true

RSpec.describe V1::MultipleCharacters::Interventions::ChangeService do
  subject { described_class.call(intervention_id, new_character, replacement_animations) }

  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let(:intervention_id) { intervention.id }

  it_behaves_like 'check change narrator service'

  context 'update current narrator' do
    let(:new_character) { 'emmi' }
    let(:replacement_animations) { { 'BodyAnimation' => { 'rest' => 'restWeightShift' } } }

    it do
      subject
      expect(intervention.reload.current_narrator).to eql(new_character)
    end
  end
end
