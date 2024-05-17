# frozen_string_literal: true

RSpec.describe V1::FlowService::NextQuestion::BranchingService do
  subject { described_class.new(question, user_session) }

  let(:participant) { create(:user, :confirmed, :participant) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let!(:intervention) { create(:intervention, user_id: researcher.id, status: status, license_type: 'unlimited') }
  let!(:session) { create(:session, intervention_id: intervention.id) }
  let(:status) { 'draft' }
  let!(:question_group) { create(:question_group, session: session) }
  let!(:question) { create(:question_single, question_group: question_group) }
  let(:user_int) { create(:user_intervention, intervention: intervention, user: participant) }
  let!(:user_session) { create(:user_session, user_id: participant.id, session_id: session.id, user_intervention: user_int) }
  let!(:answer) { create(:answer_single, question_id: question.id, user_session_id: user_session.id) }

  context 'returns finish screen if only question' do
    it { expect(subject.call.type).to eq 'Question::Finish' }

    it { expect(subject.call.id).to eq session.questions.last.id }
  end

  context 'response with question' do
    let(:questions) { create_list(:question_single, 4, question_group: question_group) }
    let!(:question) do
      question = questions.first
      question.formulas = [{ 'payload' => 'test',
                             'patterns' => [
                               {
                                 'match' => '=1',
                                 'target' => [
                                   { 'id' => questions[2].id, 'probability' => '50', 'type' => 'Question' },
                                   { 'id' => questions[3].id, 'probability' => '50', 'type' => 'Question' }
                                 ]
                               }
                             ] }]
      question.save
      question
    end

    it 'returns branched question id' do
      expect([questions[2].id, questions[3].id]).to include(subject.call.id)
    end

    context 'when target questions have draft answers' do
      let!(:answer2) { create(:answer_single, question_id: questions[2].id, user_session_id: user_session.id, draft: true) }
      let!(:answer3) { create(:answer_single, question_id: questions[3].id, user_session_id: user_session.id, draft: true) }

      it 'returns branched question id' do
        expect([questions[2].id, questions[3].id]).to include(subject.call.id)
      end
    end

    context 'when participant discover new branch' do
      let!(:answer_question1) { create(:answer_single, question_id: questions[1].id, user_session_id: user_session.id, draft: true) }

      it 'mark the answer that it belongs to alternative branch' do
        subject.call
        expect(answer_question1.reload.alternative_branch).to be(true)
      end
    end
  end

  context 'formula is not fully set' do
    let(:questions) { create_list(:question_single, 4, question_group: question_group) }
    let!(:question) do
      question = questions.first
      question.formulas = [{ 'payload' => 'test + test2',
                             'patterns' => [
                               {
                                 'match' => '=1',
                                 'target' => [{ 'id' => questions[3].id, 'probability' => '100', 'type' => 'Question' }]
                               }
                             ] }]
      question.save
      question
    end

    it 'returns next question' do
      expect(subject.call.id).to eq questions[3].id
    end

    it 'does not have warning set' do
      subject.call
      expect(subject.additional_information[:warning]).to be_nil
    end
  end

  context 'formula branching to CatMh::Session' do
    let!(:cat_session) { create(:cat_mh_session, intervention_id: intervention.id) }
    let(:questions) { create_list(:question_single, 4, question_group: question_group) }
    let!(:question) do
      question = questions.first
      question.formulas = [{ 'payload' => 'test',
                             'patterns' => [
                               {
                                 'match' => '=1',
                                 'target' => [
                                   { 'id' => cat_session.id, 'probability' => '100', 'type' => 'Session' }
                                 ]
                               }
                             ] }]
      question.save
      question
    end

    it 'returns last question' do
      expect(subject.call.id).to eq session.questions.last.id
    end

    it 'have error message' do
      subject.call
      expect(subject.additional_information[:warning]).to eq 'ForbiddenBranchingToCatMhSession'
    end
  end

  context 'intervention is published' do
    let(:status) { 'published' }

    context 'formula is not fully set and has division' do
      let(:questions) { create_list(:question_single, 4, question_group: question_group) }
      let!(:question) do
        question = questions.first
        question.formulas = [{ 'payload' => 'test/test2',
                               'patterns' => [
                                 {
                                   'match' => '=1',
                                   'target' => [{ 'id' => questions[3].id, 'probability' => '100', 'type' => 'Question' }]
                                 }
                               ] }]
        question.save
        question
      end

      it 'returns next question' do
        expect(subject.call.id).to eq questions[1].id
      end

      it 'returns correct warning' do
        subject.call
        expect(subject.additional_information[:warning]).to eq 'ZeroDivisionError'
      end
    end

    context 'uniq behavior for some type of questions' do
      let(:questions) { create_list(:question_single, 4, question_group: question_group) }
      let(:target_question_id) { questions.last.id }

      context 'formula is fully set and uses variable belongs to Question::ParticipantReport' do
        let!(:question) do
          question = create(:question_participant_report, question_group: question_group)
          question.formulas = [{ 'payload' => 'participant_rep',
                                 'patterns' => [{ 'match' => '=1',
                                                  'target' => [{ 'id' => target_question_id, 'type' => 'Question::Single', 'probability' => '100' }] }] }]
          question.body = { 'data' => [{ 'payload' => '' }], 'variable' => { 'name' => 'participant_rep' } }
          question.save
          question
        end
        let!(:answer) do
          create(:answer_participant_report, question_id: question.reload.id, user_session_id: user_session.id,
                                             migrated_body: { 'data' => [
                                               { 'var' => 'participant_rep',
                                                 'value' => { 'email' => 'example@example.com', 'receive_report' => true } }
                                             ] })
        end

        it 'returns expected question' do
          expect(subject.call.id).to eq target_question_id
        end
      end

      context 'formula is fully set and uses variable belongs to Question::Phone' do
        let!(:question) do
          question = create(:question_phone, question_group: question_group)
          question.formulas = [{ 'payload' => 'phone',
                                 'patterns' => [{ 'match' => '=1',
                                                  'target' => [{ 'id' => target_question_id, 'type' => 'Question::Single', 'probability' => '100' }] }] }]
          question.body = { 'data' => [{ 'payload' => '' }], 'variable' => { 'name' => 'phone' } }
          question.save
          question
        end
        let!(:answer) do
          create(:answer_phone, question_id: question.reload.id, user_session_id: user_session.id,
                                migrated_body: { 'data' =>
                                    [{ 'var' => 'phone',
                                       'value' => { 'time_ranges' => [{ 'from' => 7, 'to' => 9, 'label' => 'early_morning' }], 'timezone' => 'Europe/Warsaw',
                                                    'number' => '576982169', 'iso' => 'PL', 'prefix' => '+48', 'confirmed' => true } }] })
        end

        it 'returns expected question' do
          expect(subject.call.id).to eq target_question_id
        end
      end

      context 'formula is fully set and uses variable belongs to Question::ThirdParty' do
        let!(:question) do
          question = create(:question_third_party, question_group: question_group)
          question.formulas = [{ 'payload' => 'third_party',
                                 'patterns' => [{ 'match' => '=1',
                                                  'target' => [{ 'id' => target_question_id, 'type' => 'Question::Single', 'probability' => '100' }] }] }]
          question.body = { 'data' => [{ 'value' => 'email@example.com', 'numeric_value' => '1', 'payload' => '', 'report_template_ids' => [] }],
                            'variable' => { 'name' => 'third_party' } }
          question.save
          question
        end
        let!(:answer) do
          create(:answer_third_party, question_id: question.reload.id, user_session_id: user_session.id,
                                      migrated_body: { 'data' => [
                                        { 'value' => 'email@example.com',
                                          'var' => 'third_party',
                                          'numeric_value' => '1',
                                          'report_template_ids' => [], 'index' => 0 }
                                      ] })
        end

        it 'returns expected question' do
          expect(subject.call.id).to eq target_question_id
        end
      end
    end

    context 'formula is not correctly set' do
      let(:questions) { create_list(:question_single, 4, question_group: question_group) }
      let!(:question) do
        question = questions.first
        question.formulas = [{ 'payload' => 'test test2',
                               'patterns' => [
                                 {
                                   'match' => '=1',
                                   'target' => [{ 'id' => questions[3].id, 'probability' => '100', 'type' => 'Question' }]
                                 }
                               ] }]
        question.save
        question
      end

      it 'returns next question id' do
        expect(subject.call.id).to eq questions[1].id
      end

      it 'returns correct warning' do
        subject.call
        expect(subject.additional_information[:warning]).to eq 'OtherFormulaError'
      end
    end

    context 'formula branching to CatMh::Session' do
      let!(:cat_session) { create(:cat_mh_session, :with_cat_mh_info, :with_test_type_and_variables, intervention_id: intervention.id) }
      let!(:questions) { create_list(:question_single, 4, question_group: question_group) }
      let!(:question) do
        question = questions.first
        question.formulas = [{ 'payload' => 'test',
                               'patterns' => [
                                 {
                                   'match' => '=1',
                                   'target' => [
                                     { 'id' => cat_session.id, 'probability' => '100', 'type' => 'Session' }
                                   ]
                                 }
                               ] }]
        question.save
        question
      end

      it 'returns next question' do
        expect(subject.call['data']['id']).to eq 14
      end
    end

    context 'formula has invalid target' do
      let(:questions) { create_list(:question_single, 4, question_group: question_group) }
      let!(:question) do
        question = questions.first
        question.formulas = [{ 'payload' => 'test',
                               'patterns' => [
                                 {
                                   'match' => '=1',
                                   'target' => [{ 'id' => 'INVALID ID', 'probability' => '100', 'type' => 'Question' }]
                                 }
                               ] }]
        question.save
        question
      end

      it 'returns next question' do
        expect(subject.call.id).to eq questions[1].id
      end

      it 'returns correct warning' do
        subject.call
        expect(subject.additional_information[:warning]).to eq 'NoBranchingTarget'
      end
    end
  end

  context 'intervention is draft' do
    context 'formula is not fully set and has division' do
      let(:questions) { create_list(:question_single, 4, question_group: question_group) }
      let!(:question) do
        question = questions.first
        question.formulas = [{ 'payload' => 'test/test2',
                               'patterns' => [
                                 {
                                   'match' => '=1',
                                   'target' => [{ 'id' => questions[3].id, 'probability' => '100', 'type' => 'Question' }]
                                 }
                               ] }]
        question.save
        question
      end

      it 'returns next question' do
        expect(subject.call.id).to eq questions[1].id
      end

      it 'returns correct warning' do
        subject.call
        expect(subject.additional_information[:warning]).to eq 'ZeroDivisionError'
      end
    end

    context 'formula is not correctly set' do
      let(:questions) { create_list(:question_single, 4, question_group: question_group) }
      let!(:question) do
        question = questions.first
        question.formulas = [{ 'payload' => 'test test2',
                               'patterns' => [
                                 {
                                   'match' => '=1',
                                   'target' => [{ 'id' => questions[3].id, 'probability' => '100', 'type' => 'Question' }]
                                 }
                               ] }]
        question.save
        question
      end

      it 'returns next question id' do
        expect(subject.call.id).to eq questions[1].id
      end

      it 'returns correct warning' do
        subject.call
        expect(subject.additional_information[:warning]).to eq 'OtherFormulaError'
      end
    end

    context 'formula has invalid target' do
      let(:questions) { create_list(:question_single, 4, question_group: question_group) }
      let!(:question) do
        question = questions.first
        question.formulas = [{ 'payload' => 'test',
                               'patterns' => [
                                 {
                                   'match' => '=1',
                                   'target' => [{ 'id' => 'INVALID ID', 'probability' => '100', 'type' => 'Question' }]
                                 }
                               ] }]
        question.save
        question
      end

      it 'returns next question' do
        expect(subject.call.id).to eq questions[1].id
      end

      it 'returns correct warning' do
        subject.call
        expect(subject.additional_information[:warning]).to eq 'NoBranchingTarget'
      end
    end
  end

  context 'match nothing, return next' do
    let(:questions) { create_list(:question_single, 4, question_group: question_group) }
    let!(:question) do
      question = questions.first
      question.formulas = [{ 'payload' => 'test',
                             'patterns' => [
                               {
                                 'match' => '=2',
                                 'target' => [{ 'id' => questions[3].id, 'probability' => '100', 'type' => 'Question' }]
                               }
                             ] }]
      question
    end

    it { expect(subject.call.id).to eq questions[1].id }
  end

  context 'response with feedback' do
    let(:question_feedback) do
      question_feedback = build(:question_feedback, question_group: question_group, position: 2)
      question_feedback.body = {
        data: [
          {
            payload: {
              start_value: '',
              end_value: '',
              target_value: ''
            },
            spectrum: {
              payload: 'test',
              patterns: [
                {
                  match: '=1',
                  target: '111'
                }
              ]
            }
          }
        ]
      }
      question_feedback.save
      question_feedback
    end

    let(:question) do
      question = build(:question_single, question_group: question_group, position: 1)
      question.formulas = [{ 'payload' => 'test',
                             'patterns' => [
                               {
                                 'match' => '=1',
                                 'target' => [{ 'id' => question_feedback.id, 'probability' => '100',
                                                'type' => 'Question' }]
                               }
                             ] }]
      question.body = { 'data' => [{ 'value' => '1', 'payload' => '' }, { 'value' => '2', 'payload' => '' }],
                        'variable' => { 'name' => 'test' } }
      question.save
      question
    end

    it { expect(subject.call.id).to eq question_feedback.id }
  end

  context 'response when branching is set to another session' do
    let!(:other_session) do
      create(:session, intervention_id: intervention.id, position: 2, schedule: schedule, schedule_at: schedule_at)
    end
    let!(:other_question_group) { create(:question_group, session_id: other_session.id) }
    let!(:other_question) { create(:question_single, question_group_id: other_question_group.id) }

    let(:schedule) { :after_fill }
    let(:schedule_at) { DateTime.now + 1.day }

    let!(:questions) { create_list(:question_single, 3, question_group: question_group) }
    let!(:question) do
      question = questions.first
      question.formulas = [{ 'payload' => 'test',
                             'patterns' => [
                               {
                                 'match' => '=1',
                                 'target' => [{ 'id' => other_session.id, 'probability' => '100', 'type' => 'Session' }]
                               }
                             ] }]
      question.body = { 'data' => [{ 'value' => '1', 'payload' => '' }, { 'value' => '2', 'payload' => '' }],
                        'variable' => { 'name' => 'test' } }
      question.save
      question
    end

    context 'session that is branched to and has schedule after fill' do
      it {
        subject.call
        expect(subject.additional_information['next_user_session_id']).not_to eq user_session.id
      }
    end

    context 'last answer in user_session has set next_session_id' do
      it {
        subject.call
        expect(user_session.answers.last.next_session_id).to eql other_session.id
      }
    end

    context 'session that is branched to and has schedule exact date with schedule in the past' do
      let!(:schedule) { 'exact_date' }
      let(:schedule_at) { DateTime.now - 1.day }

      it {
        subject.call
        expect(subject.additional_information['next_user_session_id']).not_to eq user_session.id
      }
    end

    context 'session that is branched to and has schedule days after with schedule in the past' do
      let!(:schedule) { 'days_after' }
      let(:schedule_at) { DateTime.now - 1.day }

      it {
        subject.call
        expect(subject.additional_information['next_user_session_id']).not_to eq user_session.id
      }
    end

    %i[days_after_fill days_after exact_date].each do |schedule|
      context "session that is branched and has schedule #{schedule}" do
        let!(:schedule) { schedule }

        it 'returns question finish' do
          expect(subject.call.id).to eq session.reload.finish_screen.id
        end
      end
    end
  end
end
