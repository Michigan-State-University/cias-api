# frozen_string_literal: true

class V1::CatMh::FlowService
  attr_reader :user_session, :cat_mh_api

  ANSWER_TYPE_TO_QUESTION_TYPES = {
    1 => 'Question::Single',
    2 => 'Question::Multiple'
  }.freeze

  def initialize(user_session)
    @user_session = user_session
    @cat_mh_api = Api::CatMh.new
  end

  def user_session_question
    question = cat_mh_api.get_next_question(user_session)
    audio = V1::AudioService.call(text(question),
                                  language_code: user_session.session.google_tts_voice.language_code,
                                  voice_type: user_session.session.google_tts_voice.voice_type)
    map_cat_question(question['body'], audio)
  end

  private

  def text(question)
    question['body']['questionDescription']
  end

  def map_cat_question(cat_mh_question_hash, audio)
    {
      'data' => {
        'id' => cat_mh_question_hash['questionID'],
        'type' => 'question',
        'attributes' => {
          'type' => question_type(cat_mh_question_hash),
          'settings' => {
            'image' => false,
            'title' => true,
            'video' => false,
            'required' => true,
            'subtitle' => true,
            'proceed_button' => true,
            'narrator_skippable' => false
          },
          'title' => cat_mh_question_hash['questionNote'],
          'subtitle' => "<h1>#{cat_mh_question_hash['questionDescription']}</h1>",
          'narrator' => {
            'blocks' => [
              {
                'text' => [
                  cat_mh_question_hash['questionDescription']
                ],
                'type' => 'ReadQuestion',
                'action' => 'NO_ACTION',
                'sha256' => [
                  audio['sha256']
                ],
                'animation' => 'rest',
                'audio_urls' => [
                  audio.url
                ],
                endPosition: {
                  x: 600,
                  y: 550
                }
              }
            ],
            settings: {
              voice: true,
              animation: true
            }
          },
          'body' => {
            'data' => map_cat_answers_for_question(cat_mh_question_hash['questionAnswers'], cat_mh_question_hash['answerType']),
            'variable' => {
              name: 'variable'
            }
          }
        }
      }
    }
  end

  def map_cat_answers_for_question(answers, answer_type)
    raise ArgumentError, 'Answer type can only be 1 (Single) or 2 (Multi)' unless [1, 2].include?(answer_type)

    {
      data: answers.map.with_index(1) do |answer, index|
        case answer_type
        when 1
          {
            payload: answer['answerDescription'],
            value: answer['answerOrdinal']
          }
        when 2
          {
            payload: answer['answerDescription'],
            variable: {
              name: "answer_ordinal_#{index}",
              value: answer['answerOrdinal']
            }
          }
        end
      end
    }
  end

  def question_type(cat_mh_question_hash)
    return 'Question::Finish' if cat_mh_question_hash['questionID'] == -1

    ANSWER_TYPE_TO_QUESTION_TYPES[cat_mh_question_hash['answerType']]
  end
end
