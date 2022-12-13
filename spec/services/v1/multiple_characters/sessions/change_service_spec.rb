# frozen_string_literal: true

RSpec.describe V1::MultipleCharacters::Sessions::ChangeService do
  subject { described_class.call(session_id, new_character, replacement_animations) }

  let(:session) { create(:session) }
  let(:question_group) { create(:question_group, session: session) }
  let(:session_id) { session.id }

  it_behaves_like 'check change narrator service'

  context 'update current narrator' do
    let(:new_character) { 'emmi' }
    let(:replacement_animations) { { 'BodyAnimation' => { 'rest' => 'restWeightShift' } } }

    it do
      subject
      expect(session.reload.current_narrator).to eql(new_character)
    end
  end

  context 'when the session contains different narrators - system should change only questions with the current narrator' do
    let(:question_group) { create(:question_group, session: session) }
    let(:new_character) { 'emmi' }
    let(:replacement_animations) do
      {
        'HeadAnimation' => {
          'eatCracker' => 'acknowledge'
        }
      }
    end
    let!(:question) do
      create(:question_single, question_group: question_group,
                               narrator: { 'blocks' =>
                           [{ 'type' => 'HeadAnimation', 'animation' => 'eatCracker', 'endPosition' => { 'x' => 600, 'y' => 550 } }],
                                           'settings' => { 'voice' => true, 'animation' => true, 'character' => 'peedy' } })
    end

    let!(:question2) do
      create(:question_single, question_group: question_group,
                               narrator: { 'blocks' =>
                           [{ 'type' => 'HeadAnimation', 'animation' => 'eatCracker', 'endPosition' => { 'x' => 600, 'y' => 550 } }],
                                           'settings' => { 'voice' => true, 'animation' => true, 'character' => 'evil_peedy' } })
    end

    it do
      expect { subject }.to change { question.reload.narrator }
    end

    it do
      expect { subject }.not_to change { question2.reload.narrator }
    end
  end
end
