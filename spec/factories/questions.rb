# frozen_string_literal: true

FactoryBot.define do
  factory :question do
    intervention
    factory :question_analogue_scale do
      title { 'Analogue Scale' }
      type { Question::AnalogueScale }
    end
    factory :question_bar_graph do
      title { 'Bar Graph' }
      type { Question::BarGraph }
    end
    factory :question_blank do
      title { 'Blank' }
      type { Question::Blank }
    end
    factory :question_feedback do
      title { 'Feedback' }
      type { Question::Feedback }
    end
    factory :question_follow_up_contact do
      title { 'Follow-up contact' }
      type { Question::FollowUpContact }
    end
    factory :question_grid do
      title { 'Grid' }
      type { Question::Grid }
    end
    factory :question_multiple do
      title { 'Multiple' }
      type { Question::Multiple }
    end
    factory :question_name do
      title { 'Name' }
      type { Question::Name }
    end
    factory :question_number do
      title { 'Number' }
      type { Question::Number }
    end
    factory :question_single do
      title { 'Single' }
      type { Question::Single }
    end
    factory :question_text_box do
      title { 'TextBox' }
      type { Question::TextBox }
    end
    factory :question_url do
      title { 'Url' }
      type { Question::Url }
    end
    factory :question_video do
      title { 'Video' }
      type { Question::Video }
    end
  end
end
