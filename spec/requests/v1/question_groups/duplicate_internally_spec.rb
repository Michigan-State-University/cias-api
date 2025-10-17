# frozen_string_literal: true

RSpec.describe 'v1/question_groups/duplicate_internally', type: :request do
  context 'correctly clones all the groups from one session to another in different intervention' do
    let(:user) { create(:user, :admin, :confirmed) }
    let(:intervention) { create(:intervention, user: user) }
    let(:session) { create(:session, intervention: intervention) }
    let(:question_groups) { create_list(:question_group, 3, session: session) }
    let!(:questions) do
      [
        create(:question_feedback, question_group: question_groups[0]),
        create(:question_single, question_group: question_groups[0]),
        create(:question_date, question_group: question_groups[0]),
        create(:question_date, question_group: question_groups[1]),
        create(:question_feedback, question_group: question_groups[1]),
        create(:question_slider, question_group: question_groups[2]),
        create(:question_grid, question_group: question_groups[2]),
        create(:question_feedback, question_group: question_groups[2])
      ]
    end
    let(:other_intervention) { create(:intervention, user: user) }
    let(:target_session) { create(:session, intervention: other_intervention) }

    let(:params) do
      {
        question_groups: [
          {
            id: question_groups[0].id,
            question_ids: [questions[0].id, questions[1].id]
          },
          {
            id: question_groups[2].id,
            question_ids: [questions[6].id]
          }
        ],
        session_id: target_session.id
      }
    end

    let(:request) { post v1_question_groups_duplicate_internally_path, params: params, headers: user.create_new_auth_token }

    before { request }

    it 'returns correct HTTP status (Created)' do
      expect(response).to have_http_status(:created)
    end

    it 'correctly clones question groups from session to target_session' do
      result = target_session.reload
      # these values are accounting for finish groups
      expect(result.question_groups.count).to eq(3)
      expect(result.questions.count).to eq(4)
    end
  end

  context 'improper behaviour' do
    let(:user) { create(:user, :admin, :confirmed) }
    let(:intervention) { create(:intervention, user: user) }
    let(:session) { create(:session, intervention: intervention) }
    let(:question_groups) { create_list(:question_group, 3, session: session) }
    let!(:questions) do
      [
        create(:question_feedback, question_group: question_groups[0]),
        create(:question_single, question_group: question_groups[0]),
        create(:question_date, question_group: question_groups[0]),
        create(:question_date, question_group: question_groups[1]),
        create(:question_feedback, question_group: question_groups[1]),
        create(:question_slider, question_group: question_groups[2]),
        create(:question_grid, question_group: question_groups[2]),
        create(:question_feedback, question_group: question_groups[2])
      ]
    end
    let(:other_intervention) { create(:intervention, user: user) }
    let(:target_session) { create(:session, intervention: other_intervention) }

    let(:request) { post v1_question_groups_duplicate_internally_path, params: params, headers: user.create_new_auth_token }

    context 'fail when given a question from different group' do
      let(:params) do
        {
          question_groups: [
            {
              id: question_groups[0].id,
              question_ids: [questions[0].id, questions[7].id]
            },
            {
              id: question_groups[2].id,
              question_ids: [questions[6].id]
            }
          ],
          session_id: target_session.id
        }
      end

      it do
        request
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'fail when target intervention has multiple collaborators' do
      let(:other_intervention) { create(:intervention, :with_collaborators, user: user) }

      let(:params) do
        {
          question_groups: [
            {
              id: question_groups[0].id,
              question_ids: [questions[0].id, questions[1].id]
            },
            {
              id: question_groups[2].id,
              question_ids: [questions[6].id]
            }
          ],
          session_id: target_session.id
        }
      end

      before { request }

      it 'returns unprocessable_entity status' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns correct error message' do
        expect(json_response['message']).to eq('Cannot modify intervention with multiple collaborators. Please ensure no other users are currently editing this intervention and that you have enabled editing mode for all relevant sessions before making changes.')
      end
    end
  end
end
