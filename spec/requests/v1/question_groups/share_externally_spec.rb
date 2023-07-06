# frozen_string_literal: true

RSpec.describe 'v1/question_groups/share_externally', type: :request do
  let(:main_user) { create(:user, :admin, :confirmed) }
  let(:intervention) { create(:intervention, user: main_user) }
  let(:session) { create(:session, intervention: intervention) }
  let(:question_groups) do
    create_list(:question_group, 3, session: session)
  end
  let!(:questions) do
    [
      create(:question_slider, question_group: question_groups[0]),
      create(:question_grid, question_group: question_groups[1]),
      create(:question_date, question_group: question_groups[0]),
      create(:question_feedback, question_group: question_groups[2])
    ]
  end

  let(:target_user) { create(:user, :researcher, :confirmed) }
  let!(:target_user_intervention_count) { target_user.interventions.count }

  let(:params) do
    {
      question_groups: [
        {
          id: question_groups[0].id,
          question_ids: question_groups[0].questions.map(&:id)
        }
      ],
      emails: [target_user.email],
      session_id: session.id
    }
  end

  let(:request) do
    post v1_question_groups_share_externally_path, headers: main_user.create_new_auth_token, params: params
  end

  it 'correctly shares question groups into a new intervention for selected user' do
    request
    expect(target_user.reload.interventions.count).to eq(target_user_intervention_count + 1)
  end

  context 'when trying to share to non-permitted user' do
    let(:target_user) { create(:user, :participant, :confirmed) }

    it 'fails with Forbidden HTTP status code' do
      request
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when trying to share from unowned session' do
    let(:main_user) { create(:user, :researcher, :confirmed) }
    let(:target_intervention) { create(:intervention, user: target_user) }
    let(:target_session) { create(:session, intervention: target_intervention) }
    let(:session) { target_session }

    it 'fails with Not Found HTTP status code' do
      request
      expect(response).to have_http_status(:not_found)
    end
  end
end
