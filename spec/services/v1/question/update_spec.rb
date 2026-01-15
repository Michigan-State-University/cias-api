# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::Question::Update do
  include ActiveJob::TestHelper

  subject(:perform_service) { described_class.call(question, params) }

  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let(:question_group) { create(:question_group, session: session) }
  let(:question) { create(:question_slider, question_group: question_group) }
  let(:params) { { title: 'New title' } }

  context 'with basic param updates (e.g., on a Question::Slider)' do
    let(:question) { create(:question_slider, question_group: question_group) }

    describe 'params are valid' do
      let(:params) { { title: 'New title', subtitle: 'new subtitle' } }

      it 'updates the question' do
        perform_service
        expect(question.reload.title).to eq('New title')
        expect(question.reload.subtitle).to eq('new subtitle')
      end

      it 'does not enqueue an answer options job' do
        expect do
          perform_service
        end.not_to have_enqueued_job(UpdateJobs::AdjustQuestionAnswerOptionsReferences)
      end
    end

    describe 'params are invalid' do
      let(:params) { { title: '', subtitle: 'new subtitle' } }

      it 'raises an exception' do
        expect { perform_service }.to raise_exception(ActiveRecord::RecordInvalid)
      end
    end
  end

  context 'with answer option updates (on a Question::Multiple)' do
    let(:question) do
      create(:question_multiple, question_group: question_group, body: {
               'data' => [
                 { 'variable' => { 'name' => 'var1', 'value' => '1' }, 'payload' => 'Old Text 1' },
                 { 'variable' => { 'name' => 'var2', 'value' => '2' }, 'payload' => 'Old Text 2' }
               ]
             })
    end

    context 'when answer options have changed' do
      let(:params) do
        {
          body: {
            data: [
              { variable: { name: 'var1', value: '1' }, payload: 'Old Text 1' },
              { variable: { name: 'var2', value: '2' }, payload: 'NEW TEXT 2' }
            ]
          }
        }
      end

      it 'enqueues the AdjustQuestionAnswerOptionsReferences job with detected changes' do
        expect do
          perform_service
        end.to have_enqueued_job(UpdateJobs::AdjustQuestionAnswerOptionsReferences).with(
          question.id,
          [{ 'variable' => 'var2', 'old_payload' => 'Old Text 2', 'new_payload' => 'NEW TEXT 2', 'value' => '2' }],
          [],
          [],
          { changed: [], new: [], deleted: [] }
        )
      end

      it 'updates the question body' do
        perform_service
        expect(question.reload.body['data'][1]['payload']).to eq('NEW TEXT 2')
      end
    end

    context 'when answer options have not changed' do
      let(:params) do
        {
          body: {
            data: [
              { variable: { name: 'var1', value: '1' }, payload: 'Old Text 1' },
              { variable: { name: 'var2', value: '2' }, payload: 'Old Text 2' }
            ]
          }
        }
      end

      it 'does not enqueue the job' do
        expect do
          perform_service
        end.not_to have_enqueued_job(UpdateJobs::AdjustQuestionAnswerOptionsReferences)
      end
    end

    context 'when an answer option without a variable name is changed' do
      let(:question) do
        create(:question_multiple, question_group: question_group, body: {
                 'data' => [
                   { 'variable' => { 'name' => '', 'value' => '1' }, 'payload' => 'Old Text 1' }
                 ]
               })
      end
      let(:params) do
        {
          body: {
            data: [
              { variable: { name: '', value: '1' }, payload: 'NEW TEXT 1' }
            ]
          }
        }
      end

      it 'enqueues the job with the change (variables are empty but payload changed)' do
        expect do
          perform_service
        end.to have_enqueued_job(UpdateJobs::AdjustQuestionAnswerOptionsReferences).with(
          question.id,
          [{ 'old_payload' => 'Old Text 1', 'new_payload' => 'NEW TEXT 1', 'value' => '1' }],
          [],
          [],
          { changed: [], new: [], deleted: [] }
        )
      end
    end

    context 'when a new answer option is added' do
      let(:params) do
        {
          body: {
            data: [
              { variable: { name: 'var1', value: '1' }, payload: 'Old Text 1' },
              { variable: { name: 'var2', value: '2' }, payload: 'Old Text 2' },
              { variable: { name: 'var3', value: '3' }, payload: 'New Text 3' }
            ]
          }
        }
      end

      it 'enqueues the job with new options' do
        expect do
          perform_service
        end.to have_enqueued_job(UpdateJobs::AdjustQuestionAnswerOptionsReferences).with(
          question.id,
          [],
          [{ 'variable' => 'var3', 'payload' => 'New Text 3', 'value' => '3' }],
          [],
          { changed: [], new: [], deleted: [] }
        )
      end
    end

    context 'when an answer option is deleted' do
      let(:params) do
        {
          body: {
            data: [
              { variable: { name: 'var1', value: '1' }, payload: 'Old Text 1' }
            ]
          }
        }
      end

      it 'enqueues the job with deleted options' do
        expect do
          perform_service
        end.to have_enqueued_job(UpdateJobs::AdjustQuestionAnswerOptionsReferences).with(
          question.id,
          [],
          [],
          [{ 'name' => 'var2', 'payload' => 'Old Text 2', 'value' => '2' }],
          { changed: [], new: [], deleted: [] }
        )
      end
    end

    context 'when both value and payload change' do
      let(:params) do
        {
          body: {
            data: [
              { variable: { name: 'var1', value: '1' }, payload: 'Old Text 1' },
              { variable: { name: 'var2', value: '2_new' }, payload: 'NEW TEXT 2' }
            ]
          }
        }
      end

      it 'enqueues the job with value and payload changes' do
        expect do
          perform_service
        end.to have_enqueued_job(UpdateJobs::AdjustQuestionAnswerOptionsReferences).with(
          question.id,
          [{ 'variable' => 'var2', 'old_payload' => 'Old Text 2', 'new_payload' => 'NEW TEXT 2', 'value' => '2', 'new_value' => '2_new' }],
          [],
          [],
          { changed: [], new: [], deleted: [] }
        )
      end
    end
  end

  context 'with Grid question updates' do
    let(:question) do
      create(:question_grid, question_group: question_group, body: {
               'data' => [
                 {
                   'payload' => {
                     'rows' => [
                       { 'payload' => 'Row 1', 'variable' => { 'name' => 'row1' } },
                       { 'payload' => 'Row 2', 'variable' => { 'name' => 'row2' } }
                     ],
                     'columns' => [
                       { 'payload' => 'Col A', 'variable' => { 'value' => 'a' } },
                       { 'payload' => 'Col B', 'variable' => { 'value' => 'b' } }
                     ]
                   }
                 }
               ]
             })
    end

    context 'when a row is added' do
      let(:params) do
        {
          body: {
            data: [
              {
                payload: {
                  rows: [
                    { payload: 'Row 1', variable: { name: 'row1' } },
                    { payload: 'Row 2', variable: { name: 'row2' } },
                    { payload: 'Row 3', variable: { name: 'row3' } }
                  ],
                  columns: [
                    { payload: 'Col A', variable: { value: 'a' } },
                    { payload: 'Col B', variable: { value: 'b' } }
                  ]
                }
              }
            ]
          }
        }
      end

      it 'enqueues the job with new row' do
        expect do
          perform_service
        end.to have_enqueued_job(UpdateJobs::AdjustQuestionAnswerOptionsReferences).with(
          question.id,
          [],
          [{ 'variable' => nil, 'payload' => 'Row 3' }],
          [],
          { changed: {}, new: {}, deleted: {} }
        )
      end
    end

    context 'when a column is added' do
      let(:params) do
        {
          body: {
            data: [
              {
                payload: {
                  rows: [
                    { payload: 'Row 1', variable: { name: 'row1' } },
                    { payload: 'Row 2', variable: { name: 'row2' } }
                  ],
                  columns: [
                    { payload: 'Col A', variable: { value: 'a' } },
                    { payload: 'Col B', variable: { value: 'b' } },
                    { payload: 'Col C', variable: { value: 'c' } }
                  ]
                }
              }
            ]
          }
        }
      end

      it 'enqueues the job with new column' do
        expect do
          perform_service
        end.to have_enqueued_job(UpdateJobs::AdjustQuestionAnswerOptionsReferences).with(
          question.id,
          [],
          [],
          [],
          { changed: {}, new: [{ 'value' => 'c', 'payload' => 'Col C' }], deleted: {} }
        )
      end
    end

    context 'when a column payload changes' do
      let(:params) do
        {
          body: {
            data: [
              {
                payload: {
                  rows: [
                    { payload: 'Row 1', variable: { name: 'row1' } },
                    { payload: 'Row 2', variable: { name: 'row2' } }
                  ],
                  columns: [
                    { payload: 'Col A', variable: { value: 'a' } },
                    { payload: 'Col B UPDATED', variable: { value: 'b' } }
                  ]
                }
              }
            ]
          }
        }
      end

      it 'enqueues the job with changed column' do
        expect do
          perform_service
        end.to have_enqueued_job(UpdateJobs::AdjustQuestionAnswerOptionsReferences).with(
          question.id,
          [],
          [],
          [],
          { changed: { 'b' => { 'old' => 'Col B', 'new' => 'Col B UPDATED' } }, new: {}, deleted: {} }
        )
      end
    end

    context 'when a row is deleted' do
      let(:params) do
        {
          body: {
            data: [
              {
                payload: {
                  rows: [
                    { payload: 'Row 1', variable: { name: 'row1' } }
                  ],
                  columns: [
                    { payload: 'Col A', variable: { value: 'a' } },
                    { payload: 'Col B', variable: { value: 'b' } }
                  ]
                }
              }
            ]
          }
        }
      end

      it 'enqueues the job with deleted row' do
        expect do
          perform_service
        end.to have_enqueued_job(UpdateJobs::AdjustQuestionAnswerOptionsReferences).with(
          question.id,
          [],
          [],
          [{ 'variable' => nil, 'payload' => 'Row 2' }],
          { changed: {}, new: {}, deleted: {} }
        )
      end
    end

    context 'when a column is deleted' do
      let(:question) do
        create(:question_grid, question_group: question_group, body: {
                 'data' => [
                   {
                     'payload' => {
                       'rows' => [
                         { 'payload' => 'Row 1', 'variable' => { 'name' => 'row1' } },
                         { 'payload' => 'Row 2', 'variable' => { 'name' => 'row2' } }
                       ],
                       'columns' => [
                         { 'payload' => 'Col A', 'variable' => { 'value' => 'a' } },
                         { 'payload' => 'Col B', 'variable' => { 'value' => 'b' } },
                         { 'payload' => 'Col C', 'variable' => { 'value' => 'c' } }
                       ]
                     }
                   }
                 ]
               })
      end
      let(:params) do
        {
          body: {
            data: [
              {
                payload: {
                  rows: [
                    { payload: 'Row 1', variable: { name: 'row1' } },
                    { payload: 'Row 2', variable: { name: 'row2' } }
                  ],
                  columns: [
                    { payload: 'Col A', variable: { value: 'a' } },
                    { payload: 'Col B', variable: { value: 'b' } }
                  ]
                }
              }
            ]
          }
        }
      end

      it 'enqueues the job with deleted column' do
        expect do
          perform_service
        end.to have_enqueued_job(UpdateJobs::AdjustQuestionAnswerOptionsReferences).with(
          question.id,
          [],
          [],
          [],
          { changed: {}, new: {}, deleted: { 'c' => 'Col C' } }
        )
      end
    end
  end

  context 'when formula update is in progress (session locked)' do
    let(:question) do
      create(:question_multiple, question_group: question_group, body: {
               'data' => [
                 { 'variable' => { 'name' => 'var1', 'value' => '1' }, 'payload' => 'Old Text' }
               ]
             })
    end

    before do
      # Simulate another process already holding the lock
      session.update!(formula_update_in_progress: true)
    end

    context 'when variable names are changed' do
      let(:params) do
        {
          body: {
            data: [
              { variable: { name: 'var1_new', value: '1' }, payload: 'Old Text' }
            ]
          }
        }
      end

      it 'raises a RecordNotSaved error because lock cannot be acquired' do
        expect { perform_service }.to raise_error(ActiveRecord::RecordNotSaved, I18n.t('question.error.formula_update_in_progress'))
      end
    end

    context 'when only answer options are changed (no variable change)' do
      let(:params) do
        {
          body: {
            data: [
              { variable: { name: 'var1', value: '1' }, payload: 'New Text' }
            ]
          }
        }
      end

      it 'succeeds because no lock is needed for answer option changes only' do
        expect { perform_service }.not_to raise_error
        expect(question.reload.body['data'][0]['payload']).to eq('New Text')
      end
    end
  end
end
