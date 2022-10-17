# frozen_string_literal: true

RSpec.describe V1::MultipleCharacters::Sessions::ChangeService do
  subject { described_class.call(session_id, new_character, replacement_animations) }

  let(:session) { create(:session) }
  let(:question_group) { create(:question_group, session: session) }
  let(:session_id) { session.id }
  let(:new_character) { 'emmi' }
  let(:replacement_animations) do
    {
      'eatCracker' => 'acknowledge',
      'standStill' => 'restWeightShift'
    }
  end
  let!(:question) do
    create(:question_single, question_group: question_group,
                             narrator: { 'blocks' =>
                                        [{ 'text' => ['Enter main text/question for screen here'],
                                           'type' => 'ReadQuestion',
                                           'action' => 'NO_ACTION',
                                           'sha256' => ['5b90b52baf4f794327162dd801834ecc1991a7f93801223c3f20ffa0fa501633'],
                                           'animation' => 'pointDown',
                                           'audio_urls' =>
                                            ['/rails/active_storage/blobs/redirect/example.mp3'],
                                           'endPosition' => { 'x' => 600, 'y' => 550 } },
                                         { 'text' => [], 'type' => 'Speech', 'action' => 'NO_ACTION', 'sha256' => [], 'animation' => 'listen',
                                           'audio_urls' => [], 'endPosition' => { 'x' => 600, 'y' => 550 } },
                                         { 'type' => 'BodyAnimation', 'animation' => 'congratulate', 'endPosition' => { 'x' => 600, 'y' => 550 } },
                                         { 'type' => 'Pause', 'animation' => 'standStill', 'endPosition' => { 'x' => 600, 'y' => 550 }, 'pauseDuration' => 2 },
                                         { 'type' => 'HeadAnimation', 'animation' => 'eatCracker', 'endPosition' => { 'x' => 600, 'y' => 550 } }],
                                         'settings' => { 'voice' => true, 'animation' => true, 'character' => 'peedy' } })
  end

  context 'when all params are valid it narrator updated correctly' do
    it do
      expect { subject }.to change { question.reload.narrator }
    end

    it do
      subject
      expect(question.reload.narrator['settings']['character']).to eq(new_character)
    end

    it do
      subject
      expect(question.reload.narrator['blocks'].map { |b| b['animation'] }).to match(%w[pointDown listen congratulate restWeightShift acknowledge])
    end
  end

  context 'when passed character is wrong' do
    let(:new_character) { 'evilPeedy' }

    it do
      expect { subject }.not_to change { question.reload.narrator }
    end
  end
end
