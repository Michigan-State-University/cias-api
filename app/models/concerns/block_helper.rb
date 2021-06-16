# frozen_string_literal: true

module BlockHelper
  READ_QUESTION_BLOCK = 'ReadQuestion'
  REFLECTION_BLOCK = 'Reflection'
  REFLECTION_FORMULA_BLOCK = 'ReflectionFormula'
  SPEECH_BLOCK = 'Speech'
  BODY_ANIMATION_BLOCK = 'BodyAnimation'
  HEAD_ANIMATION_BLOCK = 'HeadAnimation'
  VOICE_BLOCKS = [READ_QUESTION_BLOCK, REFLECTION_BLOCK, REFLECTION_FORMULA_BLOCK, SPEECH_BLOCK].freeze
  ANIMATION_BLOCKS = [BODY_ANIMATION_BLOCK, HEAD_ANIMATION_BLOCK].freeze

  def voice_block?(block)
    VOICE_BLOCKS.include?(block['type'])
  end

  def animation_block?(block)
    ANIMATION_BLOCKS.include?(block['type'])
  end

  def speech?(block)
    block['type'].eql?(SPEECH_BLOCK)
  end

  def read_question?(block)
    block['type'].eql?(READ_QUESTION_BLOCK)
  end

  def reflection?(block)
    block['type'].eql?(REFLECTION_BLOCK)
  end

  def reflection_formula?(block)
    block['type'].eql?(REFLECTION_FORMULA_BLOCK)
  end

  def swap_name_into_reflectionformula_block(block, mp3url)
    swap_name_into_reflection_block(block, mp3url)
  end

  def swap_name_into_reflection_block(block, mp3url)
    block['reflections'].each do |reflection|
      next reflection unless reflection['text'].include?(':name:.')

      swap_name_into_block(reflection, mp3url)
    end
    block
  end

  def swap_name_into_speech_block(block, mp3url)
    return block unless block['text'].include?(':name:.')

    swap_name_into_block(block, mp3url)
  end

  def swap_name_into_block(block, mp3url)
    block['text'].each_with_index do |text, index|
      next text unless text == ':name:.'

      block['audio_urls'][index] = mp3url
    end
    block
  end

  def default_finish_screen_block
    {
      'action' => 'NO_ACTION',
      'animation' => 'rest',
      'text' => ['Enter main text for screen here. This is the last screen participants will see in this session'],
      'audio_urls' => [],
      'sha256' => [],
      'type' => READ_QUESTION_BLOCK,
      'endPosition' => {
        'x' => 600,
        'y' => 550
      }
    }
  end
end
