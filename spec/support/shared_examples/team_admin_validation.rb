# frozen_string_literal: true

RSpec.shared_examples 'without team admin validations' do
  subject { user.valid? }

  it 'does not call team admin validations' do
    expect(user).not_to receive(:team_is_present?)
    expect(user).not_to receive(:team_admin_already_exists?)
    subject
  end
end
