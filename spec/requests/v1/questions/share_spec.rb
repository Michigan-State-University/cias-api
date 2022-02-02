# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/questions/share', type: :request do
  let(:team_admin) { create(:user, :confirmed, :team_admin) }
  let(:team) { team_admin.admins_teams.first }
  let(:user) { create(:user, :confirmed, :researcher, team_id: team.id) }
  let(:researcher1) { create(:user, :confirmed, roles: %w[participant researcher guest], team_id: team.id) }
  let(:researcher2) { create(:user, :confirmed, :researcher, team_id: team.id) }

  let(:intervention) { create(:intervention, user: user) }
  let(:session) { create(:session, intervention: intervention) }
  let(:question_group) { create(:question_group, session: session) }
  let(:other_question_group) { create(:question_group, session: session) }
  let(:questions) { create_list(:question_single, 3, question_group: question_group) }
  let(:other_questions) { create_list(:question_single, 3, question_group: other_question_group) }

  let(:params) do
    {
      ids: questions.pluck(:id)[1, 2] << other_questions.pluck(:id)[1],
      researcher_ids: [researcher1.id, researcher2.id]
    }
  end
  let(:headers) { user.create_new_auth_token }
  let(:request) { post v1_share_questions_path, params: params, headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { post v1_share_questions_path, params: params }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end

    context 'when user shares questions to other researchers' do
      shared_examples 'no records created' do
        it 'doesn\'t create new records for any user' do
          expect { request }.not_to change(Question, :count)
          expect { request }.not_to change(QuestionGroup, :count)
          expect { request }.not_to change(Session, :count)
          expect { request }.not_to change(Intervention, :count)
        end
      end

      shared_examples 'records are created' do
        let(:researcher1_last_intervention) { researcher1.interventions.reload.last }
        let(:researcher1_last_session) { researcher1_last_intervention.sessions.last }
        let(:researcher1_first_question_group) { researcher_2_last_session.question_groups.first }

        let(:researcher_2_last_intervention) { researcher2.interventions.reload.last }
        let(:researcher_2_last_session) { researcher_2_last_intervention.sessions.last }
        let(:researcher_2_first_question_group) { researcher_2_last_session.question_groups.first }

        it 'researchers have new intervention with proper name' do
          expect(researcher1_last_intervention.attributes).to include('name' => "Copy of #{intervention.name} from #{user.full_name}")
          expect(researcher_2_last_intervention.attributes).to include('name' => "Copy of #{intervention.name} from #{user.full_name}")
        end

        it 'researchers have new session with proper name' do
          expect(researcher1_last_session.attributes).to include('name' => 'Copied Session')
          expect(researcher_2_last_session.attributes).to include('name' => 'Copied Session')
        end

        it 'researchers have new question_group with proper title' do
          expect(researcher1_first_question_group.attributes).to include('title' => 'Copied Slides')
          expect(researcher_2_first_question_group.attributes).to include('title' => 'Copied Slides')
        end

        it 'researchers have proper number of questions' do
          expect(researcher1_first_question_group.questions.count).to be(3)
          expect(researcher_2_first_question_group.questions.count).to be(3)
        end
      end

      context 'when user is super admin' do
        let(:user) { create(:user, :confirmed, :admin) }

        before { request }

        it 'returns :created status' do
          expect(response).to have_http_status(:created)
        end

        it 'returns empty response' do
          expect(response[:data]).to be(nil)
        end

        include_examples 'records are created'
      end

      context 'when user is team admin' do
        let(:user) { team_admin }

        context 'all researchers are from team' do
          before { request }

          it 'returns :created status' do
            expect(response).to have_http_status(:created)
          end

          it 'returns empty response' do
            expect(response[:data]).to be(nil)
          end

          include_examples 'records are created'
        end

        context 'one researcher isn\'t from team' do
          let(:other_researcher) { create(:user, :confirmed, :researcher) }
          let(:params) do
            {
              ids: questions.pluck(:id)[1, 2],
              researcher_ids: [researcher1.id, other_researcher.id]
            }
          end

          before { request }

          it 'returns :not_found status' do
            expect(response).to have_http_status(:not_found)
          end

          include_examples 'no records created'
        end
      end

      context 'when user is researcher' do
        context 'when researcher doesn\'t belong to any team' do
          let(:user) { create(:user, :confirmed, :researcher) }

          before { request }

          it 'returns :not_found status' do
            expect(response).to have_http_status(:not_found)
          end

          include_examples 'no records created'
        end

        context 'when researcher belongs to team' do
          context 'when params are proper' do
            before { request }

            it 'returns :created status' do
              expect(response).to have_http_status(:created)
            end

            it 'returns empty response' do
              expect(response[:data]).to be(nil)
            end

            include_examples 'records are created'
          end

          context 'when params are improper' do
            context 'shared user is not a researcher' do
              let(:params) do
                {
                  ids: questions.pluck(:id)[1, 2],
                  researcher_ids: [researcher1.id, team_admin.id]
                }
              end

              before { request }

              it 'returns :not_found status' do
                expect(response).to have_http_status(:not_found)
              end

              include_examples 'no records created'
            end

            context 'one question doesn\'t belong to current researcher' do
              let(:researcher1_intervention) { create(:intervention, user: researcher1) }
              let(:researcher1_session) { create(:session, intervention: researcher1_intervention) }
              let(:researcher1_question_group) { create(:question_group, session: researcher1_session) }
              let(:researcher1_questions) do
                create_list(:question_single, 3, question_group: researcher1_question_group)
              end

              let(:params) do
                {
                  ids: questions.pluck(:id)[1, 2] << researcher1_questions.pluck(:id)[1],
                  researcher_ids: [researcher1.id, researcher2.id]
                }
              end

              before { request }

              it 'returns :not_found status' do
                expect(response).to have_http_status(:not_found)
              end

              include_examples 'no records created'
            end

            context 'params are not given' do
              context 'only question_ids are given' do
                let(:params) do
                  {
                    ids: questions.pluck(:id)
                  }
                end

                before { request }

                it 'returns :not_found status' do
                  expect(response).to have_http_status(:not_found)
                end

                include_examples 'no records created'
              end

              context 'only researchers_ids are given' do
                let(:params) do
                  {
                    researcher_ids: [researcher1.id, researcher2.id]
                  }
                end

                before { request }

                it 'returns :not_found status' do
                  expect(response).to have_http_status(:not_found)
                end

                include_examples 'no records created'
              end
            end
          end
        end
      end

      context 'tlfb behavior' do
        let(:tlfb_group) { create(:tlfb_group, session: session) }

        context 'when user wants to share questions from tlfb group and others' do
          let(:params) do
            {
              ids: questions.pluck(:id)[1, 2] << tlfb_group.questions.pluck(:id),
              researcher_ids: [researcher1.id, researcher2.id]
            }
          end

          it 'return correct status' do
            request
            expect(response).to have_http_status(:forbidden)
          end
        end

        context 'when user wants to share only tlfb group' do
          let(:params) do
            {
              ids: tlfb_group.questions.pluck(:id),
              researcher_ids: [researcher1.id]
            }
          end

          it 'return correct status' do
            request
            expect(response).to have_http_status(:created)
          end
        end
      end
    end
  end
end
