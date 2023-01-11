# frozen_string_literal: true

module CatMh::QuestionMapping
  ANSWER_TYPE_TO_QUESTION_TYPES = {
    1 => 'Question::Single',
    2 => 'Question::Multiple'
  }.freeze

  def prepare_question(user_session, question)
    audio = if with_audio?(user_session)
              V1::AudioService.call(text(question),
                                    language_code: user_session.session.google_tts_voice.language_code,
                                    voice_type: user_session.session.google_tts_voice.voice_type)
            end
    map_cat_question(user_session, question, audio)
  end

  private

  def text(question)
    question['questionDescription']
  end

  def map_cat_question(user_session, cat_mh_question_hash, audio)
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
                  audio.nil? ? '' : audio['sha256']
                ],
                'animation' => 'rest',
                'audio_urls' => [
                  audio&.url || ''
                ],
                endPosition: {
                  x: 600,
                  y: 100
                }
              }
            ],
            settings: {
              voice: user_session.session.settings['narrator']['voice'],
              animation: user_session.session.settings['narrator']['animation'],
              character: user_session.session.current_narrator
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

    return [] if answers.blank?

    answers.map.with_index(1) do |answer, index|
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
  end

  def question_type(cat_mh_question_hash)
    return 'Question::Finish' if cat_mh_question_hash['questionID'] == -1

    ANSWER_TYPE_TO_QUESTION_TYPES[cat_mh_question_hash['answerType']]
  end

  def with_audio?(user_session)
    audio_enabled = user_session.session.settings['narrator']['voice']

    user_session.session.google_tts_voice.present? && audio_enabled
  end
end
