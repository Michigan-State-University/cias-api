# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/teams/:team_id/invitations', type: :request do
  let(:request) do
    post v1_team_invitations_path(team_id: team.id), params: params, headers: headers
  end
  let!(:researcher) { create(:user, :confirmed, roles: %w[researcher guest]) }
  let(:headers) { user.create_new_auth_token }
  let!(:team) { create(:team) }

  context 'user is admin' do
    let!(:user) { create(:user, :confirmed, :admin) }

    context 'when params are valid' do
      context 'when researcher does not exist in the system' do
        let(:params) { { email: 'newresearcher@gmail.com', roles: ['researcher'] } }
        let(:new_researcher) { User.order(created_at: :desc).first }

        it 'returns :created status' do
          request
          expect(response).to have_http_status(:created)
        end

        it 'create new researcher assigned to the team' do
          expect { request }.to change(User, :count).by(1).and \
            change { team.reload.users.count }.by(1)

          expect(new_researcher).to have_attributes(
            email: params[:email],
            team_id: team.id,
            confirmed_at: nil,
            roles: ['researcher']
          )
        end

        context 'when we want invite him as a navigator' do
          let(:params) { { email: 'newresearcher@gmail.com', roles: ['navigator'] } }
          let(:new_researcher) { User.order(created_at: :desc).first }

          it 'returns :created status' do
            request
            expect(response).to have_http_status(:created)
          end

          it 'create new researcher assigned to the team' do
            expect { request }.to change(User, :count).by(1).and \
              change { team.reload.users.count }.by(1)

            expect(new_researcher).to have_attributes(
              email: params[:email],
              team_id: team.id,
              confirmed_at: nil,
              roles: ['navigator']
            )
          end
        end

        context 'when we want invite him as a navigator and researcher' do
          let(:params) { { email: 'newresearcher@gmail.com', roles: %w[navigator researcher] } }
          let(:new_researcher) { User.order(created_at: :desc).first }

          it 'returns :created status' do
            request
            expect(response).to have_http_status(:created)
          end

          it 'create new researcher assigned to the team' do
            expect { request }.to change(User, :count).by(1).and \
              change { team.reload.users.count }.by(1)

            expect(new_researcher).to have_attributes(
              email: params[:email],
              team_id: team.id,
              confirmed_at: nil,
              roles: %w[navigator researcher]
            )
          end
        end
      end

      context 'when researcher exists in the system' do
        let(:params) { { email: researcher.email, roles: ['researcher'] } }
        let(:token) { SecureRandom.hex }
        let(:team_invitation) { TeamInvitation.order(created_at: :desc).first }

        before do
          allow_any_instance_of(TeamInvitation).to receive(:invitation_token).and_return(token)
        end

        it 'creates invitation for the existing researcher' do
          allow(TeamMailer).to receive(:invite_user).with(
            email: researcher.email,
            team: team,
            roles: ['researcher'],
            invitation_token: token
          ).and_return(double(deliver_later: nil))

          expect { request }.to change(TeamInvitation, :count).by(1).and \
            avoid_changing(User, :count).and \
              avoid_changing { team.reload.users.count }

          expect(team_invitation).to have_attributes(
            user_id: researcher.id,
            team_id: team.id
          )
        end

        context 'when researcher exist in the system and we want invite his as navigator' do
          let(:params) { { email: researcher.email, roles: ['navigator'] } }

          it 'creates invitation for the existing researcher' do
            allow(TeamMailer).to receive(:invite_user).with(
              email: researcher.email,
              team: team,
              roles: ['navigator'],
              invitation_token: token
            ).and_return(double(deliver_later: nil))

            expect { request }.to change(TeamInvitation, :count).by(1).and \
              avoid_changing(User, :count).and \
                avoid_changing { team.reload.users.count }

            expect(team_invitation).to have_attributes(
              user_id: researcher.id,
              team_id: team.id
            )
            expect(researcher.reload.roles).to include('navigator')
          end
        end
      end

      context 'researcher is already in the team' do
        let(:params) { { email: researcher.email, roles: ['researcher'] } }

        before do
          researcher.update(team_id: team.id)
        end

        it 'does not invite researcher once again' do
          expect(TeamMailer).not_to receive(:invite_user)

          expect { request }.to avoid_changing(TeamInvitation, :count).and \
            avoid_changing(User, :count).and \
              avoid_changing { team.reload.users.count }
        end
      end

      context 'researcher account is not confirmed' do
        let!(:not_confirmed_researcher) { create(:user, :researcher) }
        let(:params) { { email: not_confirmed_researcher.email, roles: ['researcher'] } }

        it 'not invite resarcher with not confirmed account' do
          expect(TeamMailer).not_to receive(:invite_user)

          expect { request }.to avoid_changing(TeamInvitation, :count).and \
            avoid_changing(User, :count).and \
              avoid_changing { team.reload.users.count }
        end
      end

      context 'user exists in the system but he\'s not a researcher' do
        let(:params) { { email: researcher.email, roles: ['researcher'] } }

        before do
          researcher.update(roles: ['participant'])
        end

        it 'user shouldn\'t be invited' do
          expect(TeamMailer).not_to receive(:invite_user)

          expect { request }.to avoid_changing(TeamInvitation, :count).and \
            avoid_changing(User, :count).and \
              avoid_changing { team.reload.users.count }
        end
      end

      context 'team invitation has been already sent' do
        context 'and not accepted yet' do
          let(:params) { { email: researcher.email, roles: ['researcher'] } }

          let!(:team_invitation) do
            create(:team_invitation, team_id: team.id, user_id: researcher.id)
          end

          it 'researcher shouldn\'t be invited again' do
            expect(TeamMailer).not_to receive(:invite_user)

            expect { request }.to avoid_changing(TeamInvitation, :count).and \
              avoid_changing(User, :count).and \
                avoid_changing { team.reload.users.count }
          end
        end

        context 'and has been accepted' do
          let(:params) { { email: researcher.email, roles: ['researcher'] } }
          let!(:accepted_team_invitation) do
            create(:team_invitation, :accepted, team_id: team.id, user_id: researcher.id)
          end
          let(:new_team_invitation) { TeamInvitation.order(created_at: :desc).first }
          let(:token) { SecureRandom.hex }

          before do
            allow_any_instance_of(TeamInvitation).to receive(:invitation_token).
              and_return(token)
          end

          it 'creates invitation for the existing researcher' do
            allow(TeamMailer).to receive(:invite_user).with(
              email: researcher.email,
              team: team,
              roles: ['researcher'],
              invitation_token: token
            ).and_return(double(deliver_later: nil))

            expect { request }.to change(TeamInvitation, :count).by(1).and \
              avoid_changing(User, :count).and \
                avoid_changing { team.reload.users.count }

            expect(new_team_invitation).to have_attributes(
              user_id: researcher.id,
              team_id: team.id
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
          avoid_changing { team.reload.users.count }
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  context 'authorization' do
    let(:params) { { email: 'newresearcher@gmail.com', roles: 'researcher' } }

    context 'when user has team admin role' do
      let(:user) { team.team_admin }

      it_behaves_like 'user who can invite researcher to the team'
    end

    context 'when user is team admin of the other team' do
      let(:other_team) { create(:team) }
      let(:user) { other_team.team_admin }

      it_behaves_like 'user who is not able to invite researcher to the team'
    end

    %i[researcher participant guest].each do |role|
      context "when user is #{role}" do
        let!(:user) { create(:user, :confirmed, role) }

        it_behaves_like 'user who is not able to invite researcher to the team'
      end
    end
  end
end
