# frozen_string_literal: true

RSpec.describe 'GET /v1/sessions/:id/variables/(:question_id)', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }

  context 'Classic sessions' do
    let!(:intervention) { create(:intervention, user: user) }
    let!(:session) { create(:session, intervention: intervention) }
    let!(:question_group) { create(:question_group, session: session, position: 1) }
    let!(:questions) do
      [
        create(:question_single, subtitle: 'single', body: { data: [{ payload: '', value: '' }], variable: { name: 'var1' } }, question_group: question_group,
                                 position: 1),
        create(:question_multiple, subtitle: 'multi',
                                   body: { data: [{ payload: '', variable: { name: 'im_a_variable', value: '' } },
                                                  { payload: '', variable: { name: 'dep', value: '' } },
                                                  { payload: '', variable: { name: 'rivia', value: '' } }] },
                                   question_group: question_group, position: 2),
        create(:question_grid, subtitle: 'grid',
                               body: { data: [{ payload: { rows: [{ payload: '', variable: { name: 'is_with_x' } },
                                                                  { payload: '', variable: { name: 'x' } }, { payload: '', variable: { name: 'y' } }],
                                                           columns: [{ payload: '', variable: { value: '1' } },
                                                                     { payload: '',
                                                                       variable: { value: '2' } }] } }] }, question_group: question_group, position: 3),
        create(:question_currency, subtitle: 'currency', body: { variable: { name: 'what' }, data: [{ payload: '' }] }, question_group: question_group,
                                   position: 4),
        create(:question_number, subtitle: 'number', body: { variable: { name: 'number' }, data: [{ payload: '' }] }, question_group: question_group,
                                 position: 5),
        create(:question_henry_ford, subtitle: 'henry_ford', body: { data: [{ payload: '', value: '12', hfh_value: 'monthly' }],
                                                                     variable: { name: 'AUDIT_1' } }, question_group: question_group, position: 1)
      ]
    end

    shared_examples 'correct classic session' do |target_size, target_vars_array, subtitles|
      let(:result) { json_response['variable_names'].flat_map { |h| h['variables'] } }
      before { request }

      it 'returns correct HTTP status code (OK)' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns correct amount of data' do
        expect(result.size).to eq(target_size)
      end

      it 'returns correct variable names' do
        expect(json_response['session_variable']).to eq(session.variable)
        expect(result).to match_array(target_vars_array)
      end

      it 'returns correct question titles' do
        expect(json_response['variable_names'].flat_map { |h| h['subtitle'] }).to match_array(subtitles)
      end
    end

    context 'without any filters' do
      let(:request) do
        get v1_fetch_variables_path(id: session.id), headers: headers
      end

      it_behaves_like 'correct classic session', 10, %w[var1 im_a_variable dep number rivia is_with_x x y what AUDIT_1],
                      %w[single multi grid currency number henry_ford]
    end

    context 'with question filters' do
      context 'without target question id' do
        let(:params) { { allow_list: %w[Question::Multiple Question::Grid] } }

        let(:request) do
          get v1_fetch_variables_path(id: session.id), headers: headers, params: params
        end

        it_behaves_like 'correct classic session', 6, %w[x y im_a_variable rivia dep is_with_x], %w[multi grid]
      end

      context 'with target question id' do
        let(:params) { { allow_list: %w[Question::Multiple Question::Grid] } }

        let(:request) do
          get v1_fetch_variables_path(id: session.id, question_id: questions[3].id), headers: headers, params: params
        end

        it_behaves_like 'correct classic session', 6, %w[x y im_a_variable rivia dep is_with_x], %w[multi grid]

        context 'and without type filters' do
          let(:request) do
            get v1_fetch_variables_path(id: session.id, question_id: questions[1].id), headers: headers
          end

          it_behaves_like 'correct classic session', 2, %w[var1 AUDIT_1], %w[single henry_ford]
        end
      end

      context 'digit only' do
        let!(:participant_report_question) do
          create(:question_participant_report, question_group: question_group, subtitle: 'participant_report',
                                               body: { data: [{ payload: '' }], variable: { name: 'participant_report_var' } })
        end
        let(:params) { { only_digit_variables: true } }
        let(:request) do
          get v1_fetch_variables_path(id: session.id), headers: headers, params: params
        end

        it_behaves_like 'correct classic session', 10, %w[var1 im_a_variable dep number rivia is_with_x x y participant_report_var AUDIT_1],
                        %w[single multi grid number participant_report henry_ford]
      end

      context 'include current question' do
        let(:params) { { include_current_question: true, question_id: questions[2].id } }
        let(:request) do
          get v1_fetch_variables_path(id: session.id), headers: headers, params: params
        end

        it_behaves_like 'correct classic session', 8, %w[var1 im_a_variable dep rivia is_with_x x y AUDIT_1], %w[single multi grid henry_ford]
      end

      context 'does not include current question' do
        let(:params) { { include_current_question: false, question_id: questions[2].id } }
        let(:request) do
          get v1_fetch_variables_path(id: session.id), headers: headers, params: params
        end

        it_behaves_like 'correct classic session', 5, %w[var1 im_a_variable dep rivia AUDIT_1], %w[single multi henry_ford]
      end

      context 'with questions outside target target question group' do
        let!(:question_group2) { create(:question_group, session: session, position: 2) }
        let!(:question_group3) { create(:question_group, session: session, position: 3) }

        let!(:questions2) do
          [
            create(:question_single, subtitle: 'var', body: { data: [{ payload: '', value: '' }], variable: { name: 'a' } }, question_group: question_group2,
                                     position: 1),
            create(:question_single, subtitle: 'bar', body: { data: [{ payload: '', value: '' }], variable: { name: 'b' } }, question_group: question_group2,
                                     position: 2),
            create(:question_single, subtitle: 'car', body: { data: [{ payload: '', value: '' }], variable: { name: 'c' } }, question_group: question_group2,
                                     position: 3)
          ]
        end
        let!(:questions3) do
          [
            create(:question_currency, subtitle: 'mar', body: { variable: { name: 'd' }, data: [{ payload: '' }] }, question_group: question_group3,
                                       position: 1),
            create(:question_number, subtitle: 'par', body: { variable: { name: 'e' }, data: [{ payload: '' }] }, question_group: question_group3,
                                     position: 2)
          ]
        end

        let(:params) { { include_current_question: true, question_id: questions2[1].id } }

        let(:request) do
          get v1_fetch_variables_path(id: session.id), headers: headers, params: params
        end

        it_behaves_like 'correct classic session', 12, %w[var1 im_a_variable dep rivia is_with_x x y what number a b AUDIT_1],
                        %w[bar currency grid multi number single var henry_ford]
      end
    end
  end

  context 'CAT-MH sessions' do
    let(:cat_mh_session) { create(:cat_mh_session, :with_test_type_and_variables, :with_mania_test_type_and_variables, :with_cat_mh_info) }
    let(:expected_cat_vars) do
      cat_mh_session.cat_mh_test_types.flat_map { |type| type.cat_mh_test_attributes.map { |var| "#{type.short_name.tr('/', '')}_#{var.name}" } }
    end
    let(:expected_cat_titles) do
      cat_mh_session.cat_mh_test_types.map(&:name)
    end
    let(:request) do
      get v1_fetch_variables_path(id: cat_mh_session.id), headers: headers
    end

    shared_examples 'correct CAT-MH session' do |target_size|
      let(:result) { json_response['variable_names'].flat_map { |h| h['variables'] } }
      before { request }

      it 'returns correct HTTP status code (OK)' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns correct amount of data' do
        expect(result.size).to eq(target_size)
      end

      it 'returns correct variable names' do
        expect(json_response['session_variable']).to eq(cat_mh_session.variable)
        expect(result).to match_array(expected_cat_vars)
      end

      it 'returns correct question titles' do
        expect(json_response['variable_names'].pluck('subtitle')).to match_array(expected_cat_titles)
      end
    end

    it_behaves_like 'correct CAT-MH session', 3

    context 'digit only' do
      let(:params) { { only_digit_variables: true } }
      let(:expected_cat_vars) do
        cat_mh_session.cat_mh_test_types.
          flat_map do |type|
          only_numeric_variables = type.cat_mh_test_attributes.filter do |var|
            var.variable_type == 'number'
          end
          only_numeric_variables.map { |var| "#{type.short_name.tr('/', '')}_#{var.name}" }
        end
      end

      let(:request) do
        get v1_fetch_variables_path(id: cat_mh_session.id), headers: headers, params: params
      end

      it_behaves_like 'correct CAT-MH session', 3
    end
  end
end
