# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/health_systems/:health_system_id/invitations/invite_health_system_admin', type: :request do
  let(:request) do
    post v1_health_system_invitations_invite_health_system_admin_path(health_system_id: health_system.id), params: params, headers: headers
  end
  let!(:organization) { create(:organization, :with_e_intervention_admin) }
  let!(:health_system) { create(:health_system, :with_health_system_admin, organization: organization) }

  let!(:admin) { create(:user, :confirmed, :admin) }
  let!(:e_intervention_admin) { organization.e_intervention_admins.first }
  let!(:health_system_admin) { create(:user, :confirmed, :health_system_admin) }

  let(:headers) { user.create_new_auth_token }
  let(:params) { { email: health_system_admin.email, health_system_id: health_system.id } }

  let(:roles) do
    {
      'admin' => admin,
      'e_intervention_admin' => e_intervention_admin
    }
  end

  context 'roles' do
    %w[admin e_intervention_admin].each do |role|
      context 'user is admin' do
        let!(:user) { roles[role] }

        context 'when params are valid' do
          context 'when health_system admin does not exist in the system' do
            let(:params) { { email: 'newhealthsystemadmin@gmail.com', health_system_id: health_system.id } }
            let(:new_health_system_admin) { User.order(created_at: :desc).first }

            it 'returns :created status' do
              request
              expect(response).to have_http_status(:created)
            end

            it 'creates new health system admin assigned to the health system' do
              expect { request }.to change(User, :count).by(1).and \
                change { health_system.reload.health_system_admins.count }.by(1)

              expect(new_health_system_admin).to have_attributes(
                email: params[:email],
                organizable_id: health_system.id,
                confirmed_at: nil,
                roles: ['health_system_admin']
              )
            end
          end

          context 'when health_system admin exists in the system' do
            let(:token) { SecureRandom.hex }
            let(:health_system_invitation) { HealthSystemInvitation.order(created_at: :desc).first }

            before do
              allow_any_instance_of(HealthSystemInvitation).to receive(:invitation_token).and_return(token)
            end

            it 'does not create invitation for the existing health_system admin' do
              expect(OrganizableMailer).not_to receive(:invite_user)

              expect { request }.to avoid_changing(HealthSystemInvitation, :count).and \
                avoid_changing(User, :count).and \
                  avoid_changing { health_system.reload.health_system_admins.count }
            end
          end

          context 'health_system admin is already in the health_system' do
            before do
              health_system_admin.update(organizable_id: health_system.id)
              health_system.health_system_admins << health_system_admin
            end

            it 'does not invite health_system admin once again' do
              expect(OrganizableMailer).not_to receive(:invite_user)

              expect { request }.to avoid_changing(HealthSystemInvitation, :count).and \
                avoid_changing(User, :count).and \
                  avoid_changing { health_system.reload.health_system_admins.count }
            end
          end

          context 'health_system admin account is not confirmed' do
            let!(:not_confirmed_health_system_admin) { create(:user, :health_system_admin) }
            let(:params) { { email: not_confirmed_health_system_admin.email, health_system_id: health_system.id } }

            it 'not invite health_system admin with not confirmed account' do
              expect(OrganizableMailer).not_to receive(:invite_user)

              expect { request }.to avoid_changing(HealthSystemInvitation, :count).and \
                avoid_changing(User, :count).and \
                  avoid_changing { health_system.reload.health_system_admins.count }
            end
          end

          context 'user exists in the system but he\'s not a health_system' do
            before do
              health_system_admin.update(roles: ['participant'])
            end

            it 'health_system admin shouldn\'t be invited again' do
              expect(OrganizableMailer).not_to receive(:invite_user)

              expect { request }.to avoid_changing(HealthSystemInvitation, :count).and \
                avoid_changing(User, :count).and \
                  avoid_changing { health_system.reload.health_system_admins.count }
            end
          end

          context 'health_system invitation has been already sent' do
            context 'and not accepted yet' do
              let!(:health_system_invitation) do
                create(:health_system_invitation, health_system_id: health_system.id, user_id: health_system_admin.id)
              end

              it 'health_system admin shouldn\'t be invited again' do
                expect(OrganizableMailer).not_to receive(:invite_user)

                expect { request }.to avoid_changing(HealthSystemInvitation, :count).and \
                  avoid_changing(User, :count).and \
                    avoid_changing { health_system.reload.health_system_admins.count }
              end
            end

            context 'and has been accepted' do
              let!(:accepted_health_system_invitation) do
                create(:health_system_invitation, :accepted, health_system_id: health_system.id, user_id: health_system_admin.id)
              end
              let(:new_health_system_invitation) { HealthSystemInvitation.order(created_at: :desc).first }
              let(:token) { SecureRandom.hex }

              before do
                allow_any_instance_of(HealthSystemInvitation).to receive(:invitation_token).
                    and_return(token)
              end

              it 'does not create invitation invitation for the existing health_system admin' do
                expect(OrganizableMailer).not_to receive(:invite_user)

                expect { request }.to avoid_changing(HealthSystemInvitation, :count).and \
                  avoid_changing(User, :count).and \
                    avoid_changing { health_system.reload.health_system_admins.count }
              end
            end
          end
        end
      end
    end
  end

  context 'when params are invalid' do
    let!(:user) { create(:user, :confirmed, :admin) }

    context 'when email is missing' do
      let(:params) { {} }

      it 'does not create new team, returns :bad_request status' do
        expect { request }.to avoid_changing(User, :count).and \
          avoid_changing { health_system.reload.health_system_admins.count }
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  context 'authorization' do
    let(:params) { { email: 'newhealthsystemadmin@gmail.com', health_system_id: health_system.id } }

    context 'when user has health_system admin role' do
      let(:user) { health_system.health_system_admins.first }

      it_behaves_like 'user who is not able to invite health_system admin to the health_system'
    end

    context 'when user is health_system admin of the other health_system' do
      let(:other_health_system) { create(:health_system, :with_health_system_admin) }
      let(:user) { other_health_system.health_system_admins.first }

      it_behaves_like 'user who is not able to invite health_system admin to the health_system'
    end

    %i[researcher participant guest].each do |role|
      context "when user is #{role}" do
        let!(:user) { create(:user, :confirmed, role) }

        it_behaves_like 'user who is not able to invite health_system admin to the health_system'
      end
    end
  end
end
