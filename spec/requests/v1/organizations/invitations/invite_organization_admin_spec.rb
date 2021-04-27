# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST/v1/organizations/:organization_id/invitations/invite_organization_admin', type: :request do
  let(:request) do
    post v1_organization_invitations_invite_organization_admin_path(organization_id: organization.id), params: params, headers: headers
  end
  let!(:organization) { create(:organization, :with_e_intervention_admin) }
  let!(:admin) { create(:user, :confirmed, :admin) }
  let!(:e_intervention_admin) { organization.e_intervention_admins.first }
  let!(:organization_admin) { create(:user, :confirmed, :organization_admin) }
  let(:headers) { user.create_new_auth_token }

  let(:roles) do
    {
      'admin' => admin,
      'e_intervention_admin' => e_intervention_admin
    }
  end

  context 'roles' do
    %w[admin e_intervention_admin].each do |role|
      context "user is #{role}" do
        let!(:user) { roles[role] }

        context 'when params are valid' do
          context 'when organization admin does not exist in the system' do
            let(:params) { { email: 'neworganizationadmin@gmail.com' } }
            let(:new_organization_admin) { User.order(created_at: :desc).first }

            it 'returns :created status' do
              request
              expect(response).to have_http_status(:created)
            end

            it 'creates new organization admin assigned to the organization' do
              expect { request }.to change(User, :count).by(1).and \
                change { organization.reload.organization_admins.count }.by(1)

              expect(new_organization_admin).to have_attributes(
                email: params[:email],
                confirmed_at: nil,
                organizable_id: organization.id,
                roles: ['organization_admin']
              )

              expect(organization.reload.organization_admins.last).to eq(new_organization_admin)
            end
          end

          context 'when organization admin exists in the system' do
            let(:params) { { email: organization_admin.email } }
            let(:token) { SecureRandom.hex }
            let(:organization_invitation) { OrganizationInvitation.order(created_at: :desc).first }

            before do
              allow_any_instance_of(OrganizationInvitation).to receive(:invitation_token).and_return(token)
            end

            it 'creates invitation for the existing organization admin' do
              expect(OrganizableMailer).to receive(:invite_user).with(
                email: organization_admin.email,
                organizable: organization,
                invitation_token: token,
                organizable_type: 'Organization'
              ).and_return(double(deliver_later: nil))

              expect { request }.to change(OrganizationInvitation, :count).by(1).and \
                avoid_changing(User, :count).and \
                  avoid_changing { organization.organization_admins.count }

              expect(organization_invitation).to have_attributes(
                user_id: organization_admin.id,
                organization_id: organization.id
              )
            end
          end

          context 'organization admin is already in the organization' do
            let(:params) { { email: organization_admin.email } }

            before do
              organization.organization_admins << organization_admin
            end

            it 'does not invite organiztaion admin once again' do
              expect(OrganizableMailer).not_to receive(:invite_user)

              expect { request }.to avoid_changing(OrganizationInvitation, :count).and \
                avoid_changing(User, :count).and \
                  avoid_changing { organization.reload.organization_admins.count }
            end
          end

          context 'organization admin account is not confirmed' do
            let!(:not_confirmed_organization_admin) { create(:user, :organization_admin) }
            let(:params) { { email: not_confirmed_organization_admin.email } }

            it 'not invite organization admin with not confirmed account' do
              expect(OrganizableMailer).not_to receive(:invite_user)

              expect { request }.to avoid_changing(OrganizationInvitation, :count).and \
                avoid_changing(User, :count).and \
                  avoid_changing { organization.reload.organization_admins.count }
            end
          end

          context 'user exists in the system but he\'s not an organization admin' do
            let(:params) { { email: organization_admin.email } }

            before do
              organization_admin.update(roles: ['researcher'])
            end

            it 'organization admin shouldn\'t be invited' do
              expect(OrganizableMailer).not_to receive(:invite_user)

              expect { request }.to avoid_changing(OrganizationInvitation, :count).and \
                avoid_changing(User, :count).and \
                  avoid_changing { organization.reload.organization_admins.count }
            end
          end

          context 'organization invitation has been already sent' do
            context 'and not accepted yet' do
              let(:params) { { email: organization_admin.email } }

              let!(:organization_invitation) do
                create(:organization_invitation, organization_id: organization.id, user_id: organization_admin.id)
              end

              it 'organization_admin shouldn\'t be invited again' do
                expect(OrganizableMailer).not_to receive(:invite_user)

                expect { request }.to avoid_changing(OrganizationInvitation, :count).and \
                  avoid_changing(User, :count).and \
                    avoid_changing { organization.reload.organization_admins.count }
              end
            end

            context 'and has been accepted' do
              let(:params) { { email: organization_admin.email } }
              let!(:accepted_organization_invitation) do
                create(:organization_invitation, :accepted, organization_id: organization.id, user_id: organization_admin.id)
              end
              let(:new_organization_invitation) { OrganizationInvitation.order(created_at: :desc).first }
              let(:token) { SecureRandom.hex }

              before do
                allow_any_instance_of(OrganizationInvitation).to receive(:invitation_token).
                    and_return(token)
              end

              it 'creates invitation for the existing organization_admin' do
                expect(OrganizableMailer).to receive(:invite_user).with(
                  email: organization_admin.email,
                  organizable: organization,
                  invitation_token: token,
                  organizable_type: 'Organization'
                ).and_return(double(deliver_later: nil))

                expect { request }.to change(OrganizationInvitation, :count).by(1).and \
                  avoid_changing(User, :count).and \
                    avoid_changing { organization.reload.organization_admins.count }

                expect(new_organization_invitation).to have_attributes(
                  user_id: organization_admin.id,
                  organization_id: organization.id
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
          avoid_changing { organization.reload.organization_admins.count }
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  context 'authorization' do
    let(:params) { { email: 'neworganizationadmin@gmail.com' } }

    context 'when user has e_intervention_admin role' do
      let(:user) { organization.e_intervention_admins.first }

      it_behaves_like 'user who is able to invite organization admin to the organization'
    end

    context 'when user is e_intervention admin of the other organization' do
      let(:other_organization) { create(:organization, :with_e_intervention_admin) }
      let(:user) { other_organization.e_intervention_admins.first }

      it_behaves_like 'user who is not able to invite organization admin to other organization'
    end

    %i[organization_admin researcher participant guest].each do |role|
      context "when user is #{role}" do
        let!(:user) { create(:user, :confirmed, role) }

        it_behaves_like 'user who is not able to invite organization admin to the organization'
      end
    end
  end
end
