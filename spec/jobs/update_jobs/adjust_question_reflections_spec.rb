# frozen_string_literal: true

RSpec.describe UpdateJobs::AdjustQuestionReflections, type: :job do
  include ActiveJob::TestHelper
  subject { described_class.perform_now(question1, prev_variable, current_variable) }

  let(:default_narrator_settings) do
    {
      'voice' => true,
      'animation' => true,
      'character' => 'peedy'
    }
  end
  let!(:question_group1) { create(:question_group, title: 'Question Group Title 1', position: 1) }
  let!(:question1) do
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
  let!(:question2) do
    create(:question_single, question_group: question_group1, subtitle: 'Question Subtitle 5', position: 2,
                             narrator: {
                               blocks: [
                                 {
                                   action: 'NO_ACTION',
                                   question_id: question1.id,
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

  context 'when Reflectable Question variable changes' do
    let!(:prev_variable) { 'var' }
    let!(:current_variable) { 'new_var' }

    before do
      question1.update!(
        body: {
          data: [
            { payload: 'a1', value: '1' },
            { payload: 'a2', value: '2' }
          ],
          variable: { name: current_variable }
        }
      )
      subject
    end

    it 'updates variable name assigned to second question by reflection' do
      expect(
        question2.reload.narrator['blocks'].pluck('reflections').map do |reflection|
          reflection.pluck('variable')
        end.flatten
      ).to include(current_variable, current_variable)
    end
  end
end
