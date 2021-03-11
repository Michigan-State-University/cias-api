# frozen_string_literal: true

RSpec.shared_examples 'without team admin validations' do
  subject { user.valid? }

  it 'does not call team admin validations' do
    expect(user).not_to receive(:team_is_present?)
    subject
  end
end
