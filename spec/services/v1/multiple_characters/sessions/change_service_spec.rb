# frozen_string_literal: true

RSpec.describe V1::MultipleCharacters::Sessions::ChangeService do
  subject { described_class.call(session_id, new_character, replacement_animations) }

  let(:session) { create(:session) }
  let(:question_group) { create(:question_group, session: session) }
  let(:session_id) { session.id }

  it_behaves_like 'check change narrator service'
end
