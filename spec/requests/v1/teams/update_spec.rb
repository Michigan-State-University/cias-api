# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/teams/:id', type: :request do
  let(:request) { patch v1_team_path(team.id), params: params, headers: headers }
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:admin_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }
  let(:user) { admin }
  let(:users) do
    {
      'admin' => admin,
      'admin_with_multiple_roles' => admin_with_multiple_roles
    }
  end
  let(:headers) { user.create_new_auth_token }
  let!(:team) { create :team }
  let(:params) do
    {
      team: {
        name: 'Best Team'
      }
    }
  end

  context 'when params' do
    %w[admin admin_with_multiple_roles].each do |role|
      let(:user) { users[role] }
      context 'valid' do
        it 'returns :ok status' do
          request
          expect(response).to have_http_status(:ok)
        end

        it 'updates team attributes' do
          expect { request }.to change { team.reload.name }.from(team.name).to('Best Team').and \
            avoid_changing { Team.count }
        end

        context 'when team admin has changed' do
          let(:params) do
            {
              team: {
                user_id: new_team_admin.id
              }
            }
          end

          context 'and new team admin is a researcher' do
            let(:previous_team_admin) { team.team_admin }
            let(:new_team_admin) { create(:user, :researcher) }

            it 'sets researcher as new team_admin and sets team_admin as researcher' do
              expect { request }.to change { new_team_admin.reload.roles }.from(['researcher']).to(['team_admin']).and \
                change { team.reload.team_admin_id }.from(previous_team_admin.id).to(new_team_admin.id).and \
                  change { previous_team_admin.reload.roles }.from(['team_admin']).to(['researcher']).and \
                    change { previous_team_admin.reload.team_id }.from(nil).to(team.id)
            end

            context 'when there are waiting team invitations for researcher' do
              let!(:team_invitation1) { create(:team_invitation, user: new_team_admin) }
              let!(:team_invitation2) { create(:team_invitation, user: new_team_admin) }
              let!(:accepted_team_invitation) { create(:team_invitation, :accepted, user: new_team_admin) }

              it 'not accepted yet invitations are removed' do
                expect { request }.to change(TeamInvitation, :count).by(-2)
                expect(team_invitation1).to be_removed
                expect(team_invitation2).to be_removed
                expect(accepted_team_invitation).to exist
              end
            end
          end

          context 'and new team admin is an other team admin' do
            let(:previous_team_admin) { team.team_admin }
            let!(:new_team_admin) { create(:user, :team_admin) }

            it 'sets team admin as new team_admin and sets an old team_admin as researcher' do
              expect { request }.to avoid_changing { new_team_admin.reload.team_id }.and \
                change { team.reload.team_admin_id }.from(previous_team_admin.id).to(new_team_admin.id).and \
                  change { previous_team_admin.reload.roles }.from(['team_admin']).to(['researcher']).and \
                    change { previous_team_admin.reload.team_id }.from(nil).to(team.id)

              expect(new_team_admin.reload.roles).to eq(['team_admin'])
            end
          end

          context 'new team admin is another team admin, old team admin is admin for another teams' do
            let(:previous_team_admin) { team.team_admin }
            let!(:second_team) { create(:team, team_admin: previous_team_admin) }
            let!(:new_team_admin) { create(:user, :team_admin) }

            it 'sets team admin as new admin of the team, old one is still team admin for another teams' do
              expect { request }.to avoid_changing { new_team_admin.reload.team_id }.and \
                change { team.reload.team_admin_id }.from(previous_team_admin.id).to(new_team_admin.id).and \
                  avoid_changing { previous_team_admin.reload.roles }

              expect(new_team_admin.reload.roles).to eq(['team_admin'])
              expect(previous_team_admin).to have_attributes(
                team_id: nil,
                roles: ['team_admin']
              )
            end
          end
        end

        context 'name param is not present' do
          let(:params) { { team: { name: '' } } }

          it 'does not update team' do
            expect_any_instance_of(Team).not_to receive(:update!)
            request
          end
        end

        context 'when name didn\'t change' do
          let(:params) { { team: { name: team.name } } }

          it 'does not update team' do
            expect_any_instance_of(Team).not_to receive(:update!)
            request
          end
        end

        context 'user_id param is not present' do
          let(:params) { { team: { user_id: '' } } }

          it 'does not update team' do
            expect_any_instance_of(User).not_to receive(:update!)
            request
          end
        end

        context 'when team admin didn\'t change' do
          let!(:team_admin) { team.team_admin }
          let(:params) { { team: { user_id: team_admin.id } } }

          it 'does not update team' do
            expect_any_instance_of(User).not_to receive(:update!)
            request
          end
        end
      end

      context 'invalid' do
        context 'params' do
          let(:params) { { team: {} } }

          it 'returns :bad_request status' do
            request
            expect(response).to have_http_status(:bad_request)
          end

          it 'does not update team attributes' do
            expect { request }.not_to change(team, :name)
          end
        end
      end
    end
  end

  context 'when team admin of current team' do
    let(:team_admin) { team.team_admin }
    let(:user) { team_admin }
    let(:researcher) { create(:user, :confirmed, :researcher) }

    context 'when name and team admin changed' do
      let(:params) do
        {
          team: {
            user_id: researcher.id,
            name: 'Best team'
          }
        }
      end

      it 'team name is changed but team admin did not' do
        expect { request }.to change { team.reload.name }.and \
          avoid_changing { team_admin.reload.roles }.and \
            avoid_changing { researcher.reload.roles }
      end
    end
  end
end
