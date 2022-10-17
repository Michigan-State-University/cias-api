# frozen_string_literal: true

RSpec.describe MultipleCharacters::ChangeNarratorJob, type: :job do
  subject { described_class.perform_now(model, object_id, new_character, new_animations) }

  let(:new_animations) do
    {
      'eatCracker' => 'acknowledge',
      'standStill' => 'restWeightShift'
    }
  end

  # before do
  #   ActiveJob::Base.queue_adapter = :test
  # end
  describe 'intervention' do
    let(:model) { Intervention.name }
    let(:object_id) { create(:intervention).id }

    it 'call correct service' do
      change_service = class_double(V1::MultipleCharacters::Interventions::ChangeService)
    end
  end
end
