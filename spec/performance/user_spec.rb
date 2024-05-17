# frozen_string_literal: true

RSpec.describe 'Performance', type: :request do
  context 'User' do
    let!(:user) { create(:user, :confirmed, :admin) }
    let!(:headers) { user.create_new_auth_token }
    let!(:users) { create_list(:user, 40, :confirmed, :participant) }

    it 'performs me in correct time' do
      expect { get v1_get_user_details_path, headers: headers }
        .to perform_under(0.2).sample(10)
    end

    it 'performs index in correct time' do
      expect { get v1_users_path, headers: headers }
        .to perform_under(0.2).sample(10)
    end

    it 'performs show in correct time' do
      expect { get v1_user_path(id: user.id), headers: headers }
        .to perform_under(0.2).sample(10)
    end
  end
end
