# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/health_clinics/:health_clinic_id/invitations/invite_health_clinic_admin', type: :request do
  let(:request) do
    post v1_health_clinic_invitations_invite_health_clinic_admin_path(health_clinic_id: health_clinic.id),
         params: params, headers: headers
  end
  let!(:organization) { create(:organization, :with_e_intervention_admin) }
  let!(:health_system) { create(:health_system, :with_health_system_admin, organization: organization) }
  let!(:health_clinic) { create(:health_clinic, :with_health_clinic_admin, health_system: health_system) }

  let!(:admin) { create(:user, :confirmed, :admin) }
  let!(:e_intervention_admin) { organization.e_intervention_admins.first }
  let!(:health_system_admin) { health_system.health_system_admins.first }
  let!(:health_clinic_admin) { create(:user, :confirmed, :health_clinic_admin) }

  let(:headers) { user.create_new_auth_token }
  let(:params) { { email: health_clinic_admin.email, health_clinic_id: health_clinic.id } }

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
          context 'when health_clinic admin does not exist in the system' do
            let(:params) { { email: 'newhealthclinicadmin@gmail.com', health_clinic_id: health_clinic.id } }
            let(:new_health_clinic_admin) { User.order(created_at: :desc).first }

            it 'returns :created status' do
              request
              expect(response).to have_http_status(:created)
            end

            it 'creates new health clinic admin assigned to the health clinic' do
              expect { request }.to change(User, :count).by(1).and \
                change { health_clinic.reload.health_clinic_admins.count }.by(1)

              expect(new_health_clinic_admin).to have_attributes(
                email: params[:email],
                organizable_id: health_clinic.id,
                confirmed_at: nil,
                roles: ['health_clinic_admin']
              )
            end
          end

          context 'when health_clinic admin exists in the system' do
            let(:token) { SecureRandom.hex }
            let(:health_clinic_invitation) { HealthClinicInvitation.order(created_at: :desc).first }

            before do
              allow_any_instance_of(HealthClinicInvitation).to receive(:invitation_token).and_return(token)
            end

            it 'creates invitation for the existing health_clinic admin' do
              allow(OrganizableMailer).to receive(:invite_user).with(
                email: health_clinic_admin.email,
                organizable: health_clinic,
                invitation_token: token,
                organizable_type: 'Health Clinic'
              ).and_return(double(deliver_later: nil))

              expect { request }.to change(HealthClinicInvitation, :count).by(1).and \
                avoid_changing(User, :count).and \
                  avoid_changing { health_clinic.reload.health_clinic_admins.count }

              expect(health_clinic_invitation).to have_attributes(
                user_id: health_clinic_admin.id,
                health_clinic_id: health_clinic.id
              )
            end
          end

          context 'health_clinic admin is already in the health_clinic' do
            before do
              health_clinic_admin.update(organizable_id: health_clinic.id)
              health_clinic.health_clinic_admins << health_clinic_admin
            end

            it 'does not invite health_clinic admin once again' do
              expect(OrganizableMailer).not_to receive(:invite_user)

              expect { request }.to avoid_changing(HealthClinicInvitation, :count).and \
                avoid_changing(User, :count).and \
                  avoid_changing { health_clinic.reload.health_clinic_admins.count }
            end
          end

          context 'health_clinic admin account is not confirmed' do
            let!(:not_confirmed_health_clinic_admin) { create(:user, :health_clinic_admin) }
            let(:params) { { email: not_confirmed_health_clinic_admin.email, health_clinic_id: health_clinic.id } }

            it 'not invite health_clinic admin with not confirmed account' do
              expect(OrganizableMailer).not_to receive(:invite_user)

              expect { request }.to avoid_changing(HealthClinicInvitation, :count).and \
                avoid_changing(User, :count).and \
                  avoid_changing { health_clinic.reload.health_clinic_admins.count }
            end
          end

          context 'user exists in the system but he\'s not a health_clinic admin' do
            before do
              health_clinic_admin.update(roles: ['participant'])
            end

            it 'health_clinic admin shouldn\'t be invited again' do
              expect(OrganizableMailer).not_to receive(:invite_user)

              expect { request }.to avoid_changing(HealthClinicInvitation, :count).and \
                avoid_changing(User, :count).and \
                  avoid_changing { health_clinic.reload.health_clinic_admins.count }
            end
          end

          context 'health_clinic invitation has been already sent' do
            context 'and not accepted yet' do
              let!(:health_clinic_invitation) do
                create(:health_clinic_invitation, health_clinic_id: health_clinic.id, user_id: health_clinic_admin.id)
              end

              it 'health_clinic admin shouldn\'t be invited again' do
                expect(OrganizableMailer).not_to receive(:invite_user)

                expect { request }.to avoid_changing(HealthClinicInvitation, :count).and \
                  avoid_changing(User, :count).and \
                    avoid_changing { health_clinic.reload.health_clinic_admins.count }
              end
            end

            context 'and has been accepted' do
              let!(:accepted_health_clinic_invitation) do
                create(:health_clinic_invitation, :accepted, health_clinic_id: health_clinic.id,
                                                             user_id: health_clinic_admin.id)
              end
              let(:new_health_clinic_invitation) { HealthClinicInvitation.order(created_at: :desc).first }
              let(:token) { SecureRandom.hex }

              before do
                allow_any_instance_of(HealthClinicInvitation).to receive(:invitation_token).
                    and_return(token)
              end

              it 'creates invitation for the existing health_clinic admin' do
                allow(OrganizableMailer).to receive(:invite_user).with(
                  email: health_clinic_admin.email,
                  organizable: health_clinic,
                  invitation_token: token,
                  organizable_type: 'Health Clinic'
                ).and_return(double(deliver_later: nil))

                expect { request }.to change(HealthClinicInvitation, :count).by(1).and \
                  avoid_changing(User, :count).and \
                    avoid_changing { health_clinic.reload.health_clinic_admins.count }

                expect(new_health_clinic_invitation).to have_attributes(
                  user_id: health_clinic_admin.id,
                  health_clinic_id: health_clinic.id
                )
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
          avoid_changing { health_clinic.reload.health_clinic_admins.count }
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  context 'authorization' do
    let(:params) { { email: 'newhealthsystemadmin@gmail.com', health_clinic_id: health_clinic.id } }

    context 'when user has health_clinic admin role' do
      let(:user) { health_clinic.health_clinic_admins.first }

      it_behaves_like 'user who is not able to invite health_clinic admin to the health_clinic'
    end

    context 'when user is health_clinic admin of the other health_clinic' do
      let(:other_health_clinic) { create(:health_clinic, :with_health_clinic_admin) }
      let(:user) { other_health_clinic.health_clinic_admins.first }

      it_behaves_like 'user who is not able to invite health_clinic admin to the health_clinic'
    end

    %i[researcher participant guest].each do |role|
      context "when user is #{role}" do
        let!(:user) { create(:user, :confirmed, role) }

        it_behaves_like 'user who is not able to invite health_clinic admin to the health_clinic'
      end
    end
  end
end
