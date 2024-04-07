# frozen_string_literal: true

RSpec.shared_examples 'cannot be assigned to sms session' do
  let(:intervention) { create(:intervention) }
  let(:session) { create(:sms_session, intervention: intervention) }
  let(:question_group) { create(:question_group, session: session) }

  it 'does not create question' do
    expect(question.save).to eq false
  end
end

RSpec.shared_examples 'can be assigned to sms session' do
  let(:intervention) { create(:intervention) }
  let(:session) { create(:sms_session, intervention: intervention) }
  let(:question_group) { create(:question_group, session: session) }

  it 'does create question' do
    expect(question.save).to eq true
  end
end

RSpec.shared_examples 'cannot be assigned to classic session' do
  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let(:question_group) { create(:question_group, session: session) }

  it 'does not create question' do
    expect(question.save).to eq false
  end
  end

RSpec.shared_examples 'can be assigned to classic session' do
  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let(:question_group) { create(:question_group, session: session) }

  it 'does create question' do
    expect(question.save).to eq true
  end
end
