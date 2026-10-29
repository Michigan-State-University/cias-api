# frozen_string_literal: true

module AnswerBodySamples
  ALL = {
    'Answer::Single' => { question: :question_single, answer: :answer_single, data: [{ 'var' => 'single_var', 'value' => '1', 'index' => 0 }] },
    'Answer::Multiple' => {
      question: :question_multiple, answer: :answer_multiple,
      data: [{ 'var' => 'multi_a', 'value' => '1', 'index' => 0 }, { 'var' => 'multi_b', 'value' => '1', 'index' => 1 }]
    },
    'Answer::FreeResponse' => {
      question: :question_free_response, answer: :answer_free_response,
      data: [{ 'var' => 'free_var', 'value' => 'Zażółć gęślą jaźń "cudzysłów" <b>tag</b> 🙂' }]
    },
    'Answer::Number' => { question: :question_number, answer: :answer_number, data: [{ 'var' => 'number_var', 'value' => 42 }] }
  }.freeze
end
