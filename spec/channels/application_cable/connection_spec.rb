# frozen_string_literal: true

describe ApplicationCable::Connection do
  %w[guest preview_session participant third_party health_clinic_admin health_system_admin
     organization_admin researcher e_intervention_admin admin].each do |role|
    context "when user is #{role}" do
      let!(:user) { create(:user, :confirmed, roles: [role]) }
      let!(:credentials) { user.create_new_auth_token }

      context 'when uid, access-token and client are valid' do
        before do
          connect "/cable?uid=#{credentials['Uid']}&access_token=#{credentials['Access-Token']}&client=#{credentials['Client']}"
        end

        it 'successfully connects' do
          expect(connection.current_user.id).to eq user.id
        end
      end

      context 'when uid, access-token or client are not given' do
        it 'rejects connection' do
          expect { connect '/cable' }.to have_rejected_connection
        end
      end

      context 'when some parameters are invalid' do
        it 'rejects connection' do
          expect { connect "/cable?uid=#{credentials['Uid']}&access_token=&client=" }.to have_rejected_connection
        end
      end
    end
  end
end
