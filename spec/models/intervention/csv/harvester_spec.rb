# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Intervention::Csv::Harvester, type: :model do
  let(:subject) { described_class.new(intervention.sessions) }
  let(:user) { create(:user, :confirmed, :admin) }

  describe '#collect_data' do
    context 'when session is Session::CatMh' do
      let!(:intervention) { create(:intervention) }
      let(:session) { create(:cat_mh_session, :with_test_type_and_variables, intervention: intervention) }
      let!(:user_session) { create(:user_session, user: user, session: session) }
      let!(:answer_body1) do
        {
          'data' => [
            {
              'var' => 'dep_severity',
              'value' => '1'
            }
          ]
        }
      end
      let!(:answer_body2) do
        {
          'data' => [
            {
              'var' => 'dep_precision',
              'value' => '2'
            }
          ]
        }
      end
      let!(:answer1) { create(:answer_cat_mh, body: answer_body1, user_session: user_session) }
      let!(:answer2) { create(:answer_cat_mh, body: answer_body2, user_session: user_session) }

      it 'save every variables and scores to csv' do
        subject.collect
        expect(subject.header).to eq [:user_id, :email, "#{session.variable}.dep_severity", "#{session.variable}.dep_precision",
                                      "#{session.variable}.metadata.session_start", "#{session.variable}.metadata.session_end",
                                      "#{session.variable}.metadata.session_duration"]
        expect(subject.rows).to eq [[user_session.user_id, user_session.user.email, '1', '2', user_session.created_at, nil, nil]]
      end
    end

    context 'when session is Session::Classic' do
      let(:questions) { Question.where(id: question.id).joins(:question_group) }
      let(:intervention) { create(:intervention) }
      let(:session) { build(:session, intervention: intervention) }
      let!(:user_session) { create(:user_session, user: user, session: session) }
      let!(:question_group) { create(:question_group_plain, session: session, position: 2) }

      context 'when single question' do
        let!(:question_body) do
          {
            'data' => [
              { 'value' => '1', 'payload' => '' },
              { 'value' => '2', 'payload' => '' }
            ],
            'variable' => { 'name' => 'test' }
          }
        end
        let!(:answer_body) do
          {
            'data' => [
              {
                'var' => 'test',
                'value' => '1'
              }
            ]
          }
        end
        let!(:question) { create(:question_single, question_group: question_group, body: question_body, position: 1) }
        let!(:answer) { create(:answer_single, question: question, body: answer_body, user_session: user_session) }

        it 'save every variables and scores to csv' do
          subject.collect
          expect(subject.header).to eq [:user_id, :email, "#{session.variable}.test", "#{session.variable}.metadata.session_start",
                                        "#{session.variable}.metadata.session_end", "#{session.variable}.metadata.session_duration"]
          expect(subject.rows).to eq [[answer.user_session.user_id, answer.user_session.user.email, '1', answer.user_session.created_at, nil, nil]]
        end

        context 'set correct order based on question group position' do
          let!(:second_question_group) { create(:question_group_plain, session: session, position: 1) }
          let!(:second_question_body) do
            {
              'data' => [
                { 'value' => '1', 'payload' => '' },
                { 'value' => '2', 'payload' => '' }
              ],
              'variable' => { 'name' => 'test_2' }
            }
          end
          let!(:second_answer_body) do
            {
              'data' => [
                {
                  'var' => 'test_2',
                  'value' => '2'
                }
              ]
            }
          end
          let!(:second_question) { create(:question_single, question_group: second_question_group, body: second_question_body, position: 2) }
          let!(:second_answer) { create(:answer_single, question: second_question, body: second_answer_body, user_session: user_session) }

          it 'save variables in correct order' do
            subject.collect
            expect(subject.header).to eq [:user_id, :email, "#{session.variable}.test_2", "#{session.variable}.test",
                                          "#{session.variable}.metadata.session_start", "#{session.variable}.metadata.session_end",
                                          "#{session.variable}.metadata.session_duration"]
            expect(subject.rows).to eq [[answer.user_session.user_id, answer.user_session.user.email, '2', '1', answer.user_session.created_at, nil, nil]]
          end
        end
      end

      context 'when multiple question' do
        let!(:question_body) do
          {
            'data' => [
              {
                'payload' => '',
                'variable' => { 'name' => 'test_1', value: '1' }
              },
              {
                'payload' => '',
                'variable' => { 'name' => 'test_2', value: '2' }
              }
            ]
          }
        end
        let!(:answer_body) do
          {
            'data' => [
              {
                'var' => 'test_1',
                'value' => '1'
              },
              {
                'var' => 'test_2',
                'value' => '2'
              }
            ]
          }
        end
        let!(:question) { create(:question_multiple, question_group: question_group, body: question_body) }
        let!(:answer) { create(:answer_multiple, question: question, body: answer_body, user_session: user_session) }

        it 'save every variables and scores to csv' do
          subject.collect
          expect(subject.header).to eq [:user_id, :email, "#{session.variable}.test_1", "#{session.variable}.test_2",
                                        "#{session.variable}.metadata.session_start", "#{session.variable}.metadata.session_end",
                                        "#{session.variable}.metadata.session_duration"]
          expect(subject.rows).to eq [[answer.user_session.user_id.to_s, answer.user_session.user.email.to_s, '1', '2', answer.user_session.created_at, nil,
                                       nil]]
        end
      end

      context 'when free response' do
        let!(:question_body) do
          {
            'data' => [
              { 'payload' => '' }
            ],
            'variable' => { 'name' => 'test_1' }
          }
        end
        let!(:answer_body) do
          {
            'data' => [
              {
                'var' => 'test_1',
                'value' => '1'
              }
            ]
          }
        end
        let!(:question) { create(:question_free_response, question_group: question_group, body: question_body) }
        let!(:answer) do
          create(:answer_free_response, question: question, body: answer_body, user_session: user_session)
        end

        it 'save every variables and scores to csv' do
          subject.collect
          expect(subject.header).to eq [:user_id, :email, "#{session.variable}.test_1", "#{session.variable}.metadata.session_start",
                                        "#{session.variable}.metadata.session_end", "#{session.variable}.metadata.session_duration"]
          expect(subject.rows).to eq [[answer.user_session.user_id.to_s, answer.user_session.user.email.to_s, '1', answer.user_session.created_at, nil, nil]]
        end
      end

      context 'when number' do
        let!(:question_body) do
          {
            'data' => [
              { 'payload' => '' }
            ],
            'variable' => { 'name' => 'test_1' }
          }
        end
        let!(:answer_body) do
          {
            'data' => [
              {
                'var' => 'test_1',
                'value' => 1
              }
            ]
          }
        end
        let!(:question) { create(:question_number, question_group: question_group, body: question_body) }
        let!(:answer) { create(:answer_number, question: question, body: answer_body, user_session: user_session) }

        it 'save every variables and scores to csv' do
          subject.collect
          expect(subject.header).to eq [:user_id, :email, "#{session.variable}.test_1", "#{session.variable}.metadata.session_start",
                                        "#{session.variable}.metadata.session_end", "#{session.variable}.metadata.session_duration"]
          expect(subject.rows).to eq [[answer.user_session.user_id, answer.user_session.user.email, 1, answer.user_session.created_at, nil, nil]]
        end
      end

      context 'when grid' do
        let!(:question_body) do
          {
            'data' => [
              {
                'payload' => {
                  'rows' => [
                    { 'payload' => '', 'variable' => { 'name' => 'test_1' } },
                    { 'payload' => '', 'variable' => { 'name' => 'test_2' } }
                  ],
                  'columns' => [
                    { 'payload' => '', 'variable' => { 'value' => '1' } },
                    { 'payload' => '', 'variable' => { 'value' => '2' } }
                  ]
                }
              }
            ]
          }
        end
        let!(:answer_body) do
          {
            'data' => [
              {
                'var' => 'test_1',
                'value' => '1'
              },
              {
                'var' => 'test_2',
                'value' => '2'
              }
            ]
          }
        end
        let!(:question) { create(:question_grid, question_group: question_group, body: question_body) }
        let!(:answer) { create(:answer_grid, question: question, body: answer_body, user_session: user_session) }

        it 'save every variables and scores to csv' do
          subject.collect
          expect(subject.header).to eq [:user_id, :email, "#{session.variable}.test_1", "#{session.variable}.test_2",
                                        "#{session.variable}.metadata.session_start", "#{session.variable}.metadata.session_end",
                                        "#{session.variable}.metadata.session_duration"]
          expect(subject.rows).to eq [[answer.user_session.user_id.to_s, answer.user_session.user.email, '1', '2', answer.user_session.created_at, nil, nil]]
        end
      end

      context 'when slider' do
        let!(:question_body) do
          {
            'data' => [
              { 'payload' => {
                'end_value' => '',
                'start_value' => ''
              } }
            ],
            'variable' => { 'name' => 'test_1' }
          }
        end
        let!(:answer_body) do
          {
            'data' => [
              {
                'var' => 'test_1',
                'value' => 1
              }
            ]
          }
        end
        let!(:question) { create(:question_slider, question_group: question_group, body: question_body) }
        let!(:answer) { create(:answer_slider, question: question, body: answer_body, user_session: user_session) }

        it 'save every variables and scores to csv' do
          subject.collect
          expect(subject.header).to eq [:user_id, :email, "#{session.variable}.test_1", "#{session.variable}.metadata.session_start",
                                        "#{session.variable}.metadata.session_end", "#{session.variable}.metadata.session_duration"]
          expect(subject.rows).to eq [[answer.user_session.user_id, answer.user_session.user.email, 1, answer.user_session.created_at, nil, nil]]
        end
      end

      context 'when external link' do
        let!(:question_body) do
          {
            'data' => [
              { 'payload' => 'www.test.pl' }
            ],
            'variable' => { 'name' => 'site' }
          }
        end
        let!(:answer_body) do
          {
            'data' => [
              {
                'var' => 'site',
                'value' => true
              }
            ]
          }
        end
        let!(:question) { create(:question_external_link, question_group: question_group, body: question_body) }
        let!(:answer) do
          create(:answer_external_link, question: question, body: answer_body, user_session: user_session)
        end

        it 'save variable and the clicking on the link to csv' do
          subject.collect
          expect(subject.header).to eq [:user_id, :email, "#{session.variable}.site", "#{session.variable}.metadata.session_start",
                                        "#{session.variable}.metadata.session_end", "#{session.variable}.metadata.session_duration"]
          expect(subject.rows).to eq [[answer.user_session.user_id.to_s, answer.user_session.user.email.to_s, true, answer.user_session.created_at, nil, nil]]
        end
      end

      context 'when date' do
        let!(:question_body) do
          {
            'data' => [
              { 'payload' => '' }
            ],
            'variable' => { 'name' => 'date' }
          }
        end
        let!(:answer_body) do
          {
            'data' => [
              {
                'var' => 'date',
                'value' => '2012-12-12'
              }
            ]
          }
        end
        let!(:question) { create(:question_date, question_group: question_group, body: question_body) }
        let!(:answer) { create(:answer_date, question: question, body: answer_body, user_session: user_session) }

        it 'save variable and the clicking on the link to csv' do
          subject.collect
          expect(subject.header).to eq [:user_id, :email, "#{session.variable}.date", "#{session.variable}.metadata.session_start",
                                        "#{session.variable}.metadata.session_end", "#{session.variable}.metadata.session_duration"]
          expect(subject.rows).to eq [[answer.user_session.user_id.to_s, answer.user_session.user.email.to_s, '2012-12-12', answer.user_session.created_at,
                                       nil, nil]]
        end
      end

      context 'when phone' do
        let!(:question_body) do
          {
            'data' => [
              { 'payload' => '' }
            ],
            'variable' => { 'name' => 'phone' }
          }
        end
        let!(:answer_body) do
          {
            'data' => [
              {
                'var' => 'phone',
                'value' => { 'iso' => 'PL', 'number' => '123123123', 'prefix' => '+48', 'confirmed' => true }
              }
            ]
          }
        end
        let!(:question) { create(:question_phone, question_group: question_group, body: question_body) }
        let!(:answer) { create(:answer_phone, question: question, body: answer_body, user_session: user_session) }

        it 'save variable and the value to csv' do
          subject.collect
          expect(subject.header).to eq [:user_id, :email, "#{session.variable}.phone", "#{session.variable}.metadata.session_start",
                                        "#{session.variable}.metadata.session_end", "#{session.variable}.metadata.session_duration"]
          expect(subject.rows).to eq [[answer.user_session.user_id.to_s, answer.user_session.user.email.to_s, '{provided_number => +48123123123}',
                                       answer.user_session.created_at, nil, nil]]
        end

        context 'with selected time ranges' do
          let!(:answer_body) do
            {
              'data' => [
                {
                  'var' => 'phone',
                  'value' => { 'iso' => 'PL',
                               'number' => '123123123',
                               'prefix' => '+48',
                               'confirmed' => true,
                               'time_ranges' => [{ 'from' => 7, 'to' => 9, 'label' => 'early_morning' }],
                               'timezone' => 'Europe/Warsaw' }
                }
              ]
            }
          end
          let!(:answer) { create(:answer_phone, question: question, body: answer_body, user_session: user_session) }

          # rubocop:disable Layout/LineLength
          it 'save variable and the value to csv' do
            subject.collect
            expect(subject.header).to eq [:user_id, :email, "#{session.variable}.phone", "#{session.variable}.metadata.session_start",
                                          "#{session.variable}.metadata.session_end", "#{session.variable}.metadata.session_duration"]
            expect(subject.rows).to eq [[answer.user_session.user_id.to_s, answer.user_session.user.email.to_s,
                                         '{provided_number => +48123123123, selected_time_ranges => [{"from"=>7, "to"=>9, "label"=>"early_morning"}], timezone => Europe/Warsaw}',
                                         answer.user_session.created_at, nil, nil]]
          end
          # rubocop:enable Layout/LineLength
        end
      end

      context 'when currency' do
        let!(:question_body) do
          {
            'data' => [
              { 'payload' => '' }
            ],
            'variable' => { 'name' => 'currency' }
          }
        end
        let!(:answer_body) do
          {
            'data' => [
              {
                'var' => 'currency',
                'value' => '1000 USD'
              }
            ]
          }
        end
        let!(:question) { create(:question_currency, question_group: question_group, body: question_body) }
        let!(:answer) { create(:answer_currency, question: question, body: answer_body, user_session: user_session) }

        it 'save variable and the value to csv' do
          subject.collect
          expect(subject.header).to eq [:user_id, :email, "#{session.variable}.currency", "#{session.variable}.metadata.session_start",
                                        "#{session.variable}.metadata.session_end", "#{session.variable}.metadata.session_duration"]
          expect(subject.rows).to eq [[answer.user_session.user_id.to_s, answer.user_session.user.email.to_s, '1000 USD', answer.user_session.created_at, nil,
                                       nil]]
        end
      end

      context 'when exist questions without answers' do
        let!(:question_1_body) do
          {
            'data' => [
              { 'value' => '1', 'payload' => '' },
              { 'value' => '2', 'payload' => '' }
            ],
            'variable' => { 'name' => 'var_1' }
          }
        end
        let!(:answer_1_body) do
          {
            'data' => [
              {
                'var' => 'var_1',
                'value' => '1'
              }
            ]
          }
        end
        let!(:question_2_body) do
          {
            'data' => [
              {
                'payload' => '',
                'variable' => { 'name' => 'var_2', value: '1' }
              },
              {
                'payload' => '',
                'variable' => { 'name' => 'var_3', value: '2' }
              }
            ]
          }
        end
        let!(:question1) do
          create(:question_single, question_group: question_group, body: question_1_body, position: 1)
        end
        let!(:question2) do
          create(:question_multiple, question_group: question_group, body: question_2_body, position: 2)
        end
        let!(:question3) { create(:question_name, question_group: question_group, position: 3) }
        let!(:questions) do
          Question.joins(:question_group).where(id: [question1.id, question2.id, question3.id]).order(:position)
        end
        let!(:answer1) do
          create(:answer_single, question: question1, body: answer_1_body, user_session: user_session)
        end
        let!(:answer2) do
          create(:answer_name, user_session: user_session, question: question3, body: { data: [
                   { 'var' => '.:name:.', 'value' => { 'name' => 'John', 'phonetic_name' => 'John' } }
                 ] })
        end

        it 'save nil values for each variable unanswered questions' do
          subject.collect
          expect(subject.header).to eq [:user_id, :email, "#{session.variable}.var_1", "#{session.variable}.var_2", "#{session.variable}.var_3",
                                        "#{session.variable}.metadata.phonetic_name", "#{session.variable}.metadata.session_start",
                                        "#{session.variable}.metadata.session_end", "#{session.variable}.metadata.session_duration"]
          expect(subject.rows).to eq [
            [
              answer1.user_session.user_id.to_s,
              answer1.user_session.user.email.to_s,
              '1', nil, nil, { 'name' => 'John', 'phonetic_name' => 'John' },
              answer1.user_session.created_at, nil, nil
            ]
          ]
        end
      end

      context 'when third party question' do
        let(:report_template) { create(:report_template, :third_party, name: 'report_name') }
        let!(:question_body) do
          { 'data' =>
             [{ 'value' => 'test@tes.com', 'payload' => '<p>Option A</p>', 'numeric_value' => '1', 'report_template_ids' => [report_template.id] },
              { 'value' => 'test2@tes.com', 'payload' => '<p>Option B</p>', 'numeric_value' => '2', 'report_template_ids' => [] }],
            'variable' => { 'name' => 'third_party' } }
        end
        let!(:answer_body) do
          { 'data' => [{ 'value' => 'test@tes.com', 'report_template_ids' => [report_template.id], 'index' => 0, 'var' => 'third_party',
                         'numeric_value' => '1' }] }
        end
        let!(:question) { create(:question_third_party, question_group: question_group, body: question_body, position: 1) }
        let!(:answer) { create(:answer_third_party, question: question, body: answer_body, user_session: user_session) }

        it 'save every variables and scores to csv' do
          subject.collect
          expect(subject.header).to eq [:user_id, :email, "#{session.variable}.third_party", "#{session.variable}.metadata.session_start",
                                        "#{session.variable}.metadata.session_end", "#{session.variable}.metadata.session_duration"]
          expect(subject.rows).to eq [[answer.user_session.user_id, answer.user_session.user.email,
                                       { 'value' => 'test@tes.com', 'numeric_value' => '1', 'report_template' => ['report_name'] },
                                       answer.user_session.created_at, nil, nil]]
        end
      end

      context 'when we have the two sessions of the same intervention' do
        let!(:question) { create(:question_single, question_group: question_group, body: question_body, position: 1) }
        let!(:answer) { create(:answer_single, question: question, body: answer_body, user_session: user_session) }
        let!(:question2) { create(:question_single, question_group: question_group2, body: question_body2, position: 2) }
        let!(:answer2) do
          create(:answer_single, question: question2, body: answer_body2, user_session: user_session2)
        end
        let(:session) { build(:session, position: 1) }
        let(:session2) { build(:session, position: 2) }
        let!(:intervention) { create(:intervention, sessions: [session, session2]) }
        let!(:user_session2) { create(:user_session, user: user, session: session2) }
        let!(:question_group2) { create(:question_group_plain, session: session2) }
        let(:question_body) do
          {
            'data' => [
              { 'value' => '1', 'payload' => '' },
              { 'value' => '2', 'payload' => '' }
            ],
            'variable' => { 'name' => 'test' }
          }
        end
        let(:answer_body) do
          {
            'data' => [
              {
                'var' => 'test',
                'value' => '1'
              }
            ]
          }
        end
        let(:question_body2) do
          {
            'data' => [
              { 'value' => '3', 'payload' => '' },
              { 'value' => '4', 'payload' => '' }
            ],
            'variable' => { 'name' => 'test_2' }
          }
        end
        let(:answer_body2) do
          {
            'data' => [
              {
                'var' => 'test_2',
                'value' => '3'
              }
            ]
          }
        end

        it 'save the values into one row' do
          subject.collect
          expect(subject.rows.size).to eq 1
          expect(subject.rows).to eq [[answer2.user_session.user_id.to_s, answer2.user_session.user.email.to_s, '1', answer.user_session.created_at, nil, nil,
                                       '3', answer2.user_session.created_at, nil, nil]]
        end
      end

      context 'when question is skipped' do
        let!(:question_body) do
          {
            'data' => [
              { 'value' => '1', 'payload' => '' },
              { 'value' => '2', 'payload' => '' }
            ],
            'variable' => { 'name' => 'test' }
          }
        end
        let!(:answer_body) do
          {
            'data' => [
              {
                'var' => 'test',
                'value' => nil
              }
            ]
          }
        end
        let!(:question) { create(:question_single, question_group: question_group, body: question_body) }
        let!(:answer) { create(:answer_single, question: question, body: answer_body, skipped: true, user_session: user_session) }

        it 'save every variables and scores to csv' do
          subject.collect
          expect(subject.header).to eq [:user_id, :email, "#{session.variable}.test", "#{session.variable}.metadata.session_start",
                                        "#{session.variable}.metadata.session_end", "#{session.variable}.metadata.session_duration"]
          expect(subject.rows).to eq [[answer.user_session.user_id, answer.user_session.user.email, 888, answer.user_session.created_at, nil, nil]]
        end
      end

      context 'when session is finished' do
        let!(:question_body) do
          {
            'data' => [
              { 'value' => '1', 'payload' => '' },
              { 'value' => '2', 'payload' => '' }
            ],
            'variable' => { 'name' => 'test' }
          }
        end
        let!(:user_session) { create(:user_session, session: session, user: user) }
        let!(:question) { create(:question_single, question_group: question_group, body: question_body) }
        let!(:answer) { create(:answer_single, question: question, skipped: true, user_session: user_session) }

        before do
          user_session.update!(finished_at: user_session.created_at + 5.hours)
        end

        it 'correctly shows an end date & session duration' do
          subject.collect
          expect(subject.header).to eq [:user_id, :email, "#{session.variable}.test", "#{session.variable}.metadata.session_start",
                                        "#{session.variable}.metadata.session_end", "#{session.variable}.metadata.session_duration"]
          expect(subject.rows).to eq [[user_session.user.id, user_session.user.email, 888, user_session.created_at, user_session.finished_at, '05:00:00']]
        end

        context 'when more than 1 session is finished' do
          let!(:question_body) do
            {
              'data' => [
                { 'value' => '1', 'payload' => '' },
                { 'value' => '2', 'payload' => '' }
              ],
              'variable' => { 'name' => 'test' }
            }
          end
          let(:subject) { described_class.new(intervention1.sessions) }
          let!(:intervention1) { create(:intervention) }
          let!(:session1) { create(:session, intervention: intervention1, position: 1) }
          let!(:user_session1) { create(:user_session, session: session1, user: user) }
          let!(:question_group1) { create(:question_group_plain, session: session1) }
          let!(:question1) { create(:question_single, question_group: question_group1, body: question_body) }
          let!(:answer1) { create(:answer_single, question: question1, skipped: true, user_session: user_session1) }
          let!(:session2) { create(:session, intervention: intervention1, position: 2) }
          let!(:question_group2) { create(:question_group_plain, session: session2) }
          let!(:user_session2) { create(:user_session, session: session2, user: user) }
          let!(:question2) { create(:question_single, question_group: question_group2, body: question_body) }
          let!(:answer2) { create(:answer_single, question: question2, skipped: true, user_session: user_session2) }
          let(:sessions) { Session.where(id: [session1.id, session2.id]).order(:position) }
          let(:expected_header) do
            [:user_id, :email, "#{session1.variable}.test", "#{session1.variable}.metadata.session_start", "#{session1.variable}.metadata.session_end",
             "#{session1.variable}.metadata.session_duration", "#{session2.variable}.test",
             "#{session2.variable}.metadata.session_start", "#{session2.variable}.metadata.session_end", "#{session2.variable}.metadata.session_duration"]
          end
          let(:expected_rows) do
            [
              [user.id, user.email, 888, user_session1.created_at, user_session1.finished_at, '05:00:00', 888, user_session2.created_at,
               user_session2.finished_at, '06:50:40']
            ]
          end

          before do
            user_session1.update!(finished_at: user_session1.created_at + 5.hours)
            user_session2.update!(finished_at: user_session2.created_at + 6.hours + 50.minutes + 40.seconds)
          end

          it 'correctly shows end dates & durations' do
            subject.collect
            expect(subject.header).to eq(expected_header)
            expect(subject.rows).to eq(Array(expected_rows))
          end
        end
      end

      context 'when no questions in session' do
        let(:sessions) { [session] }
        let(:intervention) { create(:intervention, user: user) }
        let(:session) { create(:session, intervention: intervention) }

        it 'shows start, end and duration columns in csv' do
          subject.collect
          expect(subject.header).to eq [:user_id, :email, "#{session.variable}.metadata.session_start", "#{session.variable}.metadata.session_end",
                                        "#{session.variable}.metadata.session_duration"]
          expect(subject.rows).to eq [[user.id, user.email, user_session.created_at, nil, nil]]
        end
      end

      context 'with turn on quick_exit' do
        let(:sessions) { [session] }
        let(:intervention) { create(:intervention, user: user, quick_exit: true) }
        let!(:user_session) { create(:user_session, user: user, session: session, quick_exit: true) }

        it 'shows start, end and duration columns in csv' do
          subject.collect
          expect(subject.header).to eq [:user_id, :email, "#{session.variable}.metadata.session_start", "#{session.variable}.metadata.session_end",
                                        "#{session.variable}.metadata.session_duration",
                                        "#{session.variable}.metadata.quick_exit"]
          expect(subject.rows).to eq [[user.id, user.email, user_session.created_at, nil, nil, 1]]
        end
      end

      context 'when tlfb - scenario without group' do
        let!(:question_group) { create(:tlfb_group, session: session) }
        let!(:questions) { question_group.questions }
        let!(:question_body) do
          {
            'data' => [{ 'payload' =>
                          { 'substances' => [{ 'name' => 'drug', 'variable' => 'drug' }, { 'name' => 'alcohol', 'variable' => 'alcohol' }],
                            'head_question' => 'head question',
                            'question_title' => 'question title',
                            'substance_groups' => [],
                            'substance_question' => 'question',
                            'substances_with_group' => false } }]
          }
        end
        let!(:answer_body) do
          {
            'consumptions' => [
              { 'amount' => nil, 'consumed' => true, 'variable' => 'drug' },
              { 'amount' => nil, 'consumed' => false, 'variable' => 'alcohol' }
            ],
            'substances_consumed' => true
          }
        end
        let!(:question) { questions.last.update!(body: question_body) }
        let!(:day) { create(:tlfb_day, question_group: question_group, user_session: user_session) }
        let!(:consumption_result) { create(:tlfb_consumption_result, day: day, body: answer_body) }

        it 'save every variables and scores to csv' do
          subject.collect
          expect(subject.header).to eq [:user_id, :email, "#{session.variable}.tlfb.drug_d1", "#{session.variable}.tlfb.alcohol_d1",
                                        "#{session.variable}.metadata.session_start", "#{session.variable}.metadata.session_end",
                                        "#{session.variable}.metadata.session_duration"]
          expect(subject.rows).to eq [[user.id, user.email, 1, 0, user_session.created_at, nil, nil]]
        end

        context 'csv will be generated with default value' do
          let!(:answer_body) do
            {
              'consumptions' => [
                { 'amount' => nil, 'consumed' => true, 'variable' => 'drug' }
              ],
              'substances_consumed' => true
            }
          end

          it 'save every variables and scores to csv' do
            subject.collect
            expect(subject.header).to eq [:user_id, :email, "#{session.variable}.tlfb.drug_d1", "#{session.variable}.tlfb.alcohol_d1",
                                          "#{session.variable}.metadata.session_start", "#{session.variable}.metadata.session_end",
                                          "#{session.variable}.metadata.session_duration"]
            expect(subject.rows).to eq [[user.id, user.email, 1, 0, user_session.created_at, nil, nil]]
          end
        end
      end

      context 'when tlfb - scenario with group' do
        let!(:question_group) { create(:tlfb_group, session: session) }
        let!(:questions) { question_group.questions }
        let!(:question_body) do
          {
            'data' => [{ 'payload' =>
                           {
                             'substances' => [],
                             'head_question' => 'head question',
                             'question_title' => 'question title',
                             'substance_groups' => [
                               {
                                 'name' => 'Alcohol',
                                 'substances' => [
                                   {
                                     'name' => 'vodka',
                                     'unit' => 'shots',
                                     'variable' => 'vodka'
                                   },
                                   {
                                     'name' => 'wine',
                                     'unit' => 'glasses',
                                     'variable' => 'wine'
                                   }
                                 ]
                               },
                               {
                                 'name' => 'Drugs',
                                 'substances' => [
                                   {
                                     'name' => 'cacao',
                                     'unit' => 'grams',
                                     'variable' => 'cacao'
                                   }
                                 ]
                               }
                             ],
                             'substance_question' => 'question',
                             'substances_with_group' => true
                           } }]
          }
        end
        let!(:question) { questions.last.update!(body: question_body) }
        let!(:day) { create(:tlfb_day, question_group: question_group, user_session: user_session) }

        context 'with consumption result' do
          let!(:consumption_result) { create(:tlfb_consumption_result, day: day, body: answer_body) }
          let!(:answer_body) do
            {
              'consumptions' => [
                { 'amount' => 10, 'consumed' => nil, 'variable' => 'vodka' },
                { 'amount' => 3, 'consumed' => nil, 'variable' => 'wine' },
                { 'amount' => 15, 'consumed' => nil, 'variable' => 'cacao' }
              ],
              'substances_consumed' => true
            }
          end

          it 'save every variables and scores to csv' do
            subject.collect
            expect(subject.header).to eq [:user_id, :email, "#{session.variable}.tlfb.vodka_d1", "#{session.variable}.tlfb.wine_d1",
                                          "#{session.variable}.tlfb.cacao_d1", "#{session.variable}.metadata.session_start",
                                          "#{session.variable}.metadata.session_end", "#{session.variable}.metadata.session_duration"]
            expect(subject.rows).to eq [[user.id, user.email, 10, 3, 15, user_session.created_at, nil, nil]]
          end

          context 'csv will be generated with default value' do
            let!(:answer_body) do
              {
                'consumptions' => [
                  { 'amount' => 10, 'consumed' => nil, 'variable' => 'vodka' },
                  { 'amount' => 3, 'consumed' => nil, 'variable' => 'wine' }
                ],
                'substances_consumed' => true
              }
            end

            it 'save every variables and scores to csv' do
              subject.collect
              expect(subject.header).to eq [:user_id, :email, "#{session.variable}.tlfb.vodka_d1", "#{session.variable}.tlfb.wine_d1",
                                            "#{session.variable}.tlfb.cacao_d1", "#{session.variable}.metadata.session_start",
                                            "#{session.variable}.metadata.session_end", "#{session.variable}.metadata.session_duration"]
              expect(subject.rows).to eq [[user.id, user.email, 10, 3, 0, user_session.created_at, nil, nil]]
            end
          end
        end

        context 'without consumption result' do
          it 'generate csv without answers' do
            subject.collect
            expect(subject.header).to eq [:user_id, :email, "#{session.variable}.tlfb.vodka_d1", "#{session.variable}.tlfb.wine_d1",
                                          "#{session.variable}.tlfb.cacao_d1", "#{session.variable}.metadata.session_start",
                                          "#{session.variable}.metadata.session_end", "#{session.variable}.metadata.session_duration"]
            expect(subject.rows).to eq [[user.id, user.email, nil, nil, nil, user_session.created_at, nil, nil]]
          end
        end
      end

      context 'when tlfb - simple question yes or no' do
        let!(:question_group) { create(:tlfb_group, session: session) }
        let!(:questions) { question_group.questions }
        let!(:question_body) do
          {
            'data' => [{ 'payload' =>
                           { 'head_question' => 'head question',
                             'question_title' => 'question title',
                             'substances' => [],
                             'substance_question' => 'question',
                             'substances_with_group' => false } }]
          }
        end
        let!(:answer_body) do
          {
            'consumptions' => [],
            'substances_consumed' => true
          }
        end
        let!(:question) { questions.last.update!(body: question_body) }
        let!(:day) { create(:tlfb_day, question_group: question_group, user_session: user_session) }
        let!(:consumption_result) { create(:tlfb_consumption_result, day: day, body: answer_body) }

        it 'save every variables and scores to csv' do
          subject.collect
          expect(subject.header).to eq [:user_id, :email, "#{session.variable}.tlfb.#{question_group.title_as_variable}_d1",
                                        "#{session.variable}.metadata.session_start", "#{session.variable}.metadata.session_end",
                                        "#{session.variable}.metadata.session_duration"]
          expect(subject.rows).to eq [[user.id, user.email, 1, user_session.created_at, nil, nil]]
        end
      end

      context 'when the session can be filled multiple time' do
        let(:session) { build(:session, :multiple_times, intervention: intervention) }
        let!(:question_body) do
          {
            'data' => [
              { 'value' => '1', 'payload' => '' },
              { 'value' => '2', 'payload' => '' }
            ],
            'variable' => { 'name' => 'test' }
          }
        end
        let!(:answer_body) do
          {
            'data' => [
              {
                'var' => 'test',
                'value' => '1'
              }
            ]
          }
        end
        let!(:question) { create(:question_single, question_group: question_group, body: question_body, position: 1) }
        let!(:answer) { create(:answer_single, question: question, body: answer_body, user_session: user_session) }

        it 'save every variables and scores to csv with the additional prefix' do
          subject.collect
          expect(subject.header).to eq [:user_id, :email, "#{session.variable}.approach_number_1.test",
                                        "#{session.variable}.approach_number_1.metadata.session_start",
                                        "#{session.variable}.approach_number_1.metadata.session_end",
                                        "#{session.variable}.approach_number_1.metadata.session_duration"]
          expect(subject.rows).to eq [[answer.user_session.user_id, answer.user_session.user.email, '1', answer.user_session.created_at, nil, nil]]
        end

        context 'when number of attempts is empty' do
          let!(:user_session) { create(:user_session, user: user, session: session, number_of_attempts: nil) }

          it 'save every variables and scores to csv with the additional prefix' do
            subject.collect
            expect(subject.header).to eq [:user_id, :email, "#{session.variable}.approach_number_1.test",
                                          "#{session.variable}.approach_number_1.metadata.session_start",
                                          "#{session.variable}.approach_number_1.metadata.session_end",
                                          "#{session.variable}.approach_number_1.metadata.session_duration"]
            expect(subject.rows).to eq [[answer.user_session.user_id, answer.user_session.user.email, '1', answer.user_session.created_at, nil, nil]]
          end
        end
      end

      context 'when henry ford' do
        let!(:intervention) { create(:intervention, hfhs_access: true) }
        let!(:user) { create(:user, :confirmed, :participant, :with_hfhs_patient_detail) }
        let!(:user_session) { create(:user_session, user: user, session: question.question_group.session) }
        let!(:patient_details) { user.hfhs_patient_detail }

        context 'initial screen' do
          let!(:question) { create(:question_henry_ford_initial_screen, question_group: question_group) }
          let!(:answer) { create(:answer_henry_ford_initial, question: question, user_session: user_session) }

          it 'save header and the value to csv' do
            subject.collect
            expect(subject.header).to include(:user_id, :email, 'henry_ford_health.patient_id', 'henry_ford_health.first_name', 'henry_ford_health.last_name',
                                              'henry_ford_health.gender', 'henry_ford_health.date_of_birth', 'henry_ford_health.zip_code',
                                              'henry_ford_health.phone_number', 'henry_ford_health.phone_type',
                                              "#{session.variable}.metadata.session_start", "#{session.variable}.metadata.session_end",
                                              "#{session.variable}.metadata.session_duration")

            expect(subject.rows.first).to include(user.id, user.email, patient_details.patient_id, patient_details.first_name, patient_details.last_name,
                                                  patient_details.dob, patient_details.sex, patient_details.zip_code, patient_details.phone_number,
                                                  patient_details.phone_type, user_session.created_at, nil, nil)
          end

          context 'unfinished user_session - without assigned hfhs_user_detail' do
            let!(:user) { create(:user, :confirmed, :participant) }

            it 'save header and nil value to csv' do
              subject.collect
              expect(subject.header).to include(:user_id, :email, 'henry_ford_health.patient_id', 'henry_ford_health.first_name', 'henry_ford_health.last_name',
                                                'henry_ford_health.gender', 'henry_ford_health.date_of_birth', 'henry_ford_health.zip_code',
                                                "#{session.variable}.metadata.session_start", "#{session.variable}.metadata.session_end",
                                                "#{session.variable}.metadata.session_duration")

              expect(subject.rows.first).to include(user.id, user.email, nil, nil, nil,
                                                    nil, nil, nil, user_session.created_at, nil, nil)
            end
          end
        end

        context 'question' do
          let!(:question_body) do
            {
              'data' => [
                { 'value' => '1', 'payload' => '', 'hfh_value' => '' },
                { 'value' => '2', 'payload' => '', 'hfh_value' => '' }
              ],
              'variable' => { 'name' => 'test_hf' }
            }
          end
          let!(:answer_body) do
            {
              'data' => [
                {
                  'var' => 'test_hf',
                  'value' => '1'
                }
              ]
            }
          end
          let!(:question) { create(:question_henry_ford, question_group: question_group, body: question_body, position: 1) }
          let!(:answer) { create(:answer_henry_ford, question: question, body: answer_body, user_session: user_session) }

          it 'save every variables and scores to csv' do
            subject.collect
            expect(subject.header).to eq [:user_id, :email, "#{session.variable}.test_hf", "#{session.variable}.metadata.session_start",
                                          "#{session.variable}.metadata.session_end", "#{session.variable}.metadata.session_duration"]
            expect(subject.rows).to eq [[answer.user_session.user_id, answer.user_session.user.email, '1', answer.user_session.created_at, nil, nil]]
          end
        end
      end

      context 'user_sessions are in order' do
        let!(:user_session) { create(:user_session, session: session, created_at: 2.days.ago) }
        let!(:user_session2) { create(:user_session, session: session, created_at: 1.day.ago) }
        let!(:user_session3) { create(:user_session, session: session, created_at: 5.days.ago) }

        it 'save every variables and scores to csv' do
          subject.collect
          expect(subject.header).to eq [:user_id, :email, "#{session.variable}.metadata.session_start", "#{session.variable}.metadata.session_end",
                                        "#{session.variable}.metadata.session_duration"]
          expect(subject.rows).to eq [[user_session3.user_id, user_session3.user.email, user_session3.created_at, nil, nil],
                                      [user_session.user_id, user_session.user.email, user_session.created_at, nil, nil],
                                      [user_session2.user_id, user_session2.user.email, user_session2.created_at, nil, nil]]
        end
      end
    end
  end
end
