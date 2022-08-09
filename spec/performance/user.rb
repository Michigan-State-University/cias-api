# frozen_string_literal: true

RSpec.describe 'Performance', type: :request do
  context 'Me' do
    let!(:user) { create(:user, :confirmed, :admin) }

    it 'performs in correct time' do
      expect { get v1_get_user_details_path, headers: user.create_new_auth_token }.to perform_under(0.25).sample(10)
    end
  end
end
