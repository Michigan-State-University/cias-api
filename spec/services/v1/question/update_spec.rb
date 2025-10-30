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
        end.not_to have_enqueued_job(UpdateJobs::AdjustQuestionAnswerOptions)
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

      let(:expected_changes) { { 'var2' => { 'Old Text 2' => 'NEW TEXT 2' } } }

      it 'enqueues the AdjustQuestionAnswerOptions job with correct changes' do
        expect do
          perform_service
        end.to have_enqueued_job(UpdateJobs::AdjustQuestionAnswerOptions).with(
          question.id,
          expected_changes
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
        end.not_to have_enqueued_job(UpdateJobs::AdjustQuestionAnswerOptions)
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

      it 'does not enqueue the job' do
        expect do
          perform_service
        end.not_to have_enqueued_job(UpdateJobs::AdjustQuestionAnswerOptions)
      end
    end
  end

  context 'when formula update is in progress' do
    let(:question) do
      create(:question_multiple, question_group: question_group, body: {
               'data' => [
                 { 'variable' => { 'name' => 'var1', 'value' => '1' }, 'payload' => 'Old Text' }
               ]
             })
    end

    before do
      allow_any_instance_of(described_class).to receive(:formula_update_in_progress?).and_return(true)
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

      it 'raises a RecordNotSaved error' do
        expect { perform_service }.to raise_error(ActiveRecord::RecordNotSaved, I18n.t('question.error.formula_update_in_progress'))
      end
    end

    context 'when answer options are changed' do
      let(:params) do
        {
          body: {
            data: [
              { variable: { name: 'var1', value: '1' }, payload: 'New Text' }
            ]
          }
        }
      end

      it 'raises a RecordNotSaved error' do
        expect { perform_service }.to raise_error(ActiveRecord::RecordNotSaved, I18n.t('question.error.formula_update_in_progress'))
      end
    end
  end
end
