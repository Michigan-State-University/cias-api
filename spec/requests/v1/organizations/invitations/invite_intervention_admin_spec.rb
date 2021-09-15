# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/organizations/:organization_id/invitations/invite_intervention_admin', type: :request do
  let(:request) do
    post v1_organization_invitations_invite_intervention_admin_path(organization_id: organization.id), params: params,
                                                                                                       headers: headers
  end
  let!(:organization) { create(:organization, :with_organization_admin) }
  let(:headers) { user.create_new_auth_token }
  let!(:intervention_admin) { create(:user, :confirmed, :e_intervention_admin) }

  context 'user is admin' do
    let!(:user) { create(:user, :confirmed, :admin) }

    context 'when params are valid' do
      context 'when e-intervention admin does not exist in the system' do
        let(:params) { { email: 'neweinterventionadmin@gmail.com' } }
        let(:new_intervention_admin) { User.order(created_at: :desc).first }

        it 'returns :created status' do
          request
          expect(response).to have_http_status(:created)
        end

        it 'creates new e-intervention admin assigned to the organization' do
          expect { request }.to change(User, :count).by(1).and \
            change { organization.reload.e_intervention_admins.count }.by(1)

          expect(new_intervention_admin).to have_attributes(
            email: params[:email],
            organizable_id: organization.id,
            confirmed_at: nil,
            roles: ['e_intervention_admin'],
            active: false
          )
        end
      end

      context 'when e-intervention admin exists in the system' do
        let(:params) { { email: intervention_admin.email } }
        let(:token) { SecureRandom.hex }
        let(:organization_invitation) { OrganizationInvitation.order(created_at: :desc).first }

        before do
          allow_any_instance_of(OrganizationInvitation).to receive(:invitation_token).and_return(token)
        end

        it 'creates invitation for the existing e-intervention admin' do
          allow(OrganizableMailer).to receive(:invite_user).with(
            email: intervention_admin.email,
            organizable: organization,
            invitation_token: token,
            organizable_type: 'Organization'
          ).and_return(double(deliver_later: nil))

          expect { request }.to change(OrganizationInvitation, :count).by(1).and \
            avoid_changing(User, :count).and \
              change { organization.reload.e_intervention_admins.count }.by(1)

          expect(organization_invitation).to have_attributes(
            user_id: intervention_admin.id,
            organization_id: organization.id
          )
        end
      end

      context 'intervention_admin is already in the organization' do
        let(:params) { { email: intervention_admin.email } }

        before do
          intervention_admin.update(organizable_id: organization.id)
          organization.e_intervention_admins << intervention_admin
        end

        it 'does not invite intervention_admin once again' do
          expect(OrganizableMailer).not_to receive(:invite_user)

          expect { request }.to avoid_changing(OrganizationInvitation, :count).and \
            avoid_changing(User, :count).and \
              avoid_changing { organization.reload.e_intervention_admins.count }
        end
      end

      context 'intervention_admin belongs to other organization' do
        let_it_be(:organization2) { create(:organization, :with_e_intervention_admin) }
        let(:e_intervention_admin_2) { organization2.e_intervention_admins.first }
        let(:token) { SecureRandom.hex }
        let(:params) { { email: e_intervention_admin_2.email } }
        let(:organization_invitation) { OrganizationInvitation.order(created_at: :desc).first }

        before do
          allow_any_instance_of(OrganizationInvitation).to receive(:invitation_token).and_return(token)
        end

        it 'creates invitation for the existing e-intervention admin' do
          expect(OrganizableMailer).to receive(:invite_user).with(
            email: e_intervention_admin_2.email,
            organizable: organization,
            invitation_token: token,
            organizable_type: 'Organization'
          ).and_return(double(deliver_later: nil))

          expect { request }.to change(OrganizationInvitation, :count).by(1).and \
            avoid_changing(User, :count).and \
              change { organization.reload.e_intervention_admins.count }.by(1)

          expect(organization_invitation).to have_attributes(
            user_id: e_intervention_admin_2.id,
            organization_id: organization.id
          )

          expect(e_intervention_admin_2.organizations.size).to be(2)
        end
      end

      context 'intervention_admin account is not confirmed' do
        let!(:not_confirmed_intervention_admin) { create(:user, :e_intervention_admin) }
        let(:params) { { email: not_confirmed_intervention_admin.email } }

        it 'not invite intervention_admin with not confirmed account' do
          expect(OrganizableMailer).not_to receive(:invite_user)

          expect { request }.to avoid_changing(OrganizationInvitation, :count).and \
            avoid_changing(User, :count).and \
              change { organization.reload.e_intervention_admins.count }.by(1)
        end
      end

      context 'user exists in the system but he\'s not a intervention_admin/researcher' do
        let(:params) { { email: intervention_admin.email } }

        before do
          intervention_admin.update(roles: ['participant'])
        end

        it 'organization admin shouldn\'t be invited again' do
          expect(OrganizableMailer).not_to receive(:invite_user)

          expect { request }.to avoid_changing(OrganizationInvitation, :count).and \
            avoid_changing(User, :count).and \
              avoid_changing { organization.reload.e_intervention_admins.count }
        end
      end

      context 'organization invitation has been already sent' do
        context 'and not accepted yet' do
          let(:params) { { email: intervention_admin.email } }

          let!(:organization_invitation) do
            create(:organization_invitation, organization_id: organization.id, user_id: intervention_admin.id)
          end

          it 'intervention_admin shouldn\'t be invited again' do
            expect(OrganizableMailer).not_to receive(:invite_user)

            expect { request }.to avoid_changing(OrganizationInvitation, :count).and \
              avoid_changing(User, :count).and \
                change { organization.reload.e_intervention_admins.count }.by(1)
          end
        end

        context 'and has been accepted' do
          let(:params) { { email: intervention_admin.email } }
          let!(:accepted_organization_invitation) do
            create(:organization_invitation, :accepted, organization_id: organization.id,
                                                        user_id: intervention_admin.id)
          end
          let(:new_organization_invitation) { OrganizationInvitation.order(created_at: :desc).first }
          let(:token) { SecureRandom.hex }

          before do
            allow_any_instance_of(OrganizationInvitation).to receive(:invitation_token).
                and_return(token)
          end

          it 'creates invitation for the existing intervention_admin' do
            allow(OrganizableMailer).to receive(:invite_user).with(
              email: intervention_admin.email,
              organizable: organization,
              invitation_token: token,
              organizable_type: 'Organization'
            ).and_return(double(deliver_later: nil))

            expect { request }.to change(OrganizationInvitation, :count).by(1).and \
              avoid_changing(User, :count).and \
                change { organization.reload.e_intervention_admins.count }.by(1)

            expect(new_organization_invitation).to have_attributes(
              user_id: intervention_admin.id,
              organization_id: organization.id
            )
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
          avoid_changing { organization.reload.e_intervention_admins.count }
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  context 'authorization' do
    let(:params) { { email: 'newresearcher@gmail.com' } }

    context 'when user has organization admin role' do
      let(:user) { organization.organization_admins.first }

      it_behaves_like 'user who is not able to invite e-intervention admin to the organization'
    end

    context 'when user is organization admin of the other organization' do
      let(:other_organization) { create(:organization, :with_organization_admin) }
      let(:user) { other_organization.organization_admins.first }

      it_behaves_like 'user who is not able to invite e-intervention admin to the organization'
    end

    %i[researcher participant guest].each do |role|
      context "when user is #{role}" do
        let!(:user) { create(:user, :confirmed, role) }

        it_behaves_like 'user who is not able to invite e-intervention admin to the organization'
      end
    end
  end
end
