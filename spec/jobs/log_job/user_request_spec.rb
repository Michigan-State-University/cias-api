# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LogJob::UserRequest, type: :job do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:params) do
    {
      user_id: user.id,
      controller: 'v1/sessions',
      action: 'index',
      query_string: {},
      params: {
        'session' => {}
      },
      user_agent: 'insomnia/7.1.1',
      remote_ip: '::1'
    }
  end

  describe 'when correct params, create record' do
    subject { described_class.perform_now(params) }

    it { should be_valid }
  end
end
