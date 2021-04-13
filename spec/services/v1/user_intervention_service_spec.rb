# frozen_string_literal: true

RSpec.describe V1::UserInterventionService do
  subject{ described_class.new(user.id, intervention.id, user_session2.id) }

  describe '#var_values' do
    let(:user) { create(:user) }
    let(:intervention) { create(:intervention) }
    let!(:session1) { create(:session, intervention: intervention, variable: 's1234') }
    let!(:session2) { create(:session, intervention: intervention) }
    let(:user_session1) { create(:user_session, user: user, session: session1) }
    let!(:user_session2) { create(:user_session, user: user, session: session2) }
    let!(:question_group1) { create(:question_group, session: session1) }
    let!(:question_group2) { create(:question_group, session: session2) }
    let!(:question_body1) do
      {
        'data' => [{ 'value' => '5', 'payload' => '' }],
        'variable' => { 'name' => 'var1' }
      }
    end
    let!(:question_body2) do
      {
        'data' => [{ 'value' => '5', 'payload' => '' }],
        'variable' => { 'name' => 'var2' }
      }
    end
    let!(:question1) { create(:question_single, question_group: question_group1, body: question_body1) }
    let!(:question2) { create(:question_single, question_group: question_group2, body: question_body2) }
    let!(:answer_body1) do
      {
        'data' => [
          {
            'var' => 'var2',
            'value' => '5'
          }
        ]
      }
    end
    let!(:answer_body2) do
      {
        'data' => [
          {
            'var' => 'var2',
            'value' => '5'
          }
        ]
      }
    end
    let!(:answer1) do
      create(:answer_single, question: question1, body: answer_body1, user_session: user_session1)
    end
    let!(:answer2) do
      create(:answer_single, question: question2, body: answer_body2, user_session: user_session2)
    end
    let!(:expected_var_values) do
      {
        's1234.var2' => '5',
        'var2' => '5'
      }
    end

    it 'correctly selected var values' do
      expect(subject.var_values).to eq expected_var_values
    end
  end
end
