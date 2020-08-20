# frozen_string_literal: true

require 'rails_helper'

class Google::Cloud::TextToSpeech::V1::SynthesizeSpeechResponse::Fake
  def audio_content
    SecureRandom.uuid
  end
end

RSpec.describe 'PATCH /v1/interventions/:intervention_id/questions/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }

  let(:q_narrator_turn_off) { create(:question_single, :narrator_turn_off) }
  let(:q_narrator_blocks_empty) { create(:question_single, :narrator_blocks_empty) }
  let(:q_narrator_block_one) { create(:question_single, :narrator_block_one) }
  let(:q_narrator_block_one_another_type) { create(:question_single, :narrator_block_one_another_type) }
  let(:q_narrator_blocks_types) { create(:question_single, :narrator_blocks_types) }
  let(:q_narrator_blocks_with_speech_empty) { create(:question_single, :narrator_blocks_with_speech_empty) }

  let(:i_narrator_turn_off) { q_narrator_turn_off.intervention }
  let(:i_narrator_blocks_empty) { q_narrator_blocks_empty.intervention }
  let(:i_narrator_block_one) { q_narrator_block_one.intervention }
  let(:i_narrator_block_one_another_type) { q_narrator_block_one_another_type.intervention }
  let(:i_narrator_blocks_types) { q_narrator_blocks_types.intervention }
  let(:i_narrator_blocks_with_speech_empty) { q_narrator_blocks_with_speech_empty.intervention }

  let(:headers) do
    user.create_new_auth_token
  end

  let(:params_turn_off) do
    {
      question: {
        narrator: {
          blocks: [
            {
              text: ['Medicine is the science and practice of establishing the diagnosis, prognosis, treatment, and prevention of disease.', 'Working together as an interdisciplinary team, many highly trained health professionals'],
              sha256: %w[80fc22b48738e42f920aca2c00b189ae565a268c45334e4cb5d056bede799cd2 cff0c9ce9f8394e5a6797002a2150c9ce6b7b2b072ece4f6a67b93be25aa0046],
              audio_urls: ['spec/factories/audio/80fc22b48738e42f920aca2c00b189ae565a268c45334e4cb5d056bede799cd2.mp3', 'spec/factories/audio/cff0c9ce9f8394e5a6797002a2150c9ce6b7b2b072ece4f6a67b93be25aa0046.mp3'],
              type: 'Speech'
            },
            {
              text: [],
              type: 'BodyAnimation',
              sha256: [],
              audio_urls: []
            }
          ],
          settings: {
            voice: false,
            animation: true
          }
        }
      }
    }
  end

  let(:params_turn_on) do
    {
      question: {
        narrator: {
          blocks: [],
          settings: {
            voice: true,
            animation: true
          }
        }
      }
    }
  end

  let(:params_empty_block) do
    {
      question: {
        narrator: {
          blocks: [],
          settings: {
            voice: true,
            animation: true
          }
        }
      }
    }
  end

  let(:params_speech) do
    {
      question: {
        narrator: {
          blocks: [
            {
              type: 'Speech',
              text: ['Farewell.'],
              sha256: ['52ea67359dfa70ce35169fd2493590d8371919161a7fb2e28e322863448b9a87'],
              animation: '',
              audio_urls: ['/rails/active_storage/blobs/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaEpJaWsxTmpKbE5UZ3dOaTFqTXprM0xUUm1PRGd0T0dGaE1TMDNZV1V6WXpoaE9UTTFZVGdHT2daRlZBPT0iLCJleHAiOm51bGwsInB1ciI6ImJsb2JfaWQifX0=--7e7f58df7135dc8738895a6aab5373c2595cdddf/52ea67359dfa70ce35169fd2493590d8371919161a7fb2e28e322863448b9a87.mp3']
            }
          ],
          settings: { voice: true, animation: true }
        }
      }
    }
  end

  let(:params_another) do
    {
      question: {
        narrator: {
          blocks: [
            { text: [],
              type: 'BodyAnimation',
              sha256: [],
              animation: '',
              audio_urls: [] }
          ],
          settings: {
            voice: true,
            animation: true
          }
        }
      }
    }
  end

  let(:params_speech_read_question) do
    {
      question: {
        narrator: {
          blocks: [
            {
              text: ['Farewell.', 'Mind yourself.'],
              type: 'Speech',
              sha256: %w[52ea67359dfa70ce35169fd2493590d8371919161a7fb2e28e322863448b9a87 7bffc2b191a07860fbcaae942775be40389b953b290aa774dbeabf57b57ba59d],
              animation: '',
              audio_urls: ['/rails/active_storage/blobs/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaEpJaWsxTmpKbE5UZ3dOaTFqTXprM0xUUm1PRGd0T0dGaE1TMDNZV1V6WXpoaE9UTTFZVGdHT2daRlZBPT0iLCJleHAiOm51bGwsInB1ciI6ImJsb2JfaWQifX0=--7e7f58df7135dc8738895a6aab5373c2595cdddf/52ea67359dfa70ce35169fd2493590d8371919161a7fb2e28e322863448b9a87.mp3', '/rails/active_storage/blobs/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaEpJaWt3WWpnNFpEUTVOQzFsTlRBMExUUmxaV1l0T1RNNE1TMWlZbVprWkRKaE4yRTJOalFHT2daRlZBPT0iLCJleHAiOm51bGwsInB1ciI6ImJsb2JfaWQifX0=--eb8a91e9b042434f6142608b388efe99b5a266d7/7bffc2b191a07860fbcaae942775be40389b953b290aa774dbeabf57b57ba59d.mp3']
            },
            {
              text: ["That chip of yours, I wouldn't wager it on Blackjack...Unless the dealer has a five of six showing."],
              type: 'ReadQuestion',
              sha256: [],
              animation: '',
              audio_urls: []
            }
          ],
          settings: {
            voice: true,
            animation: true
          }
        }
      }
    }
  end

  let(:params_another_speech) do
    {
      question: {
        narrator: {
          blocks: [
            {
              text: [],
              type: 'BodyAnimation',
              sha256: [],
              animation: [],
              audio_urls: []
            },
            {
              text: ["That chip of yours, I wouldn't wager it on Blackjack...Unless the dealer has a five of six showing."],
              type: 'Speech',
              sha256: [],
              animation: '',
              audio_urls: []
            }
          ],
          settings: {
            voice: true,
            animation: true
          }
        }
      }
    }
  end

  let(:params_speech_another) do
    {
      question: {
        narrator: {
          blocks: [
            {
              type: 'Speech',
              text: ['Farewell.'],
              sha256: ['52ea67359dfa70ce35169fd2493590d8371919161a7fb2e28e322863448b9a87'],
              animation: '',
              audio_urls: ['/rails/active_storage/blobs/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaEpJaWsxTmpKbE5UZ3dOaTFqTXprM0xUUm1PRGd0T0dGaE1TMDNZV1V6WXpoaE9UTTFZVGdHT2daRlZBPT0iLCJleHAiOm51bGwsInB1ciI6ImJsb2JfaWQifX0=--7e7f58df7135dc8738895a6aab5373c2595cdddf/52ea67359dfa70ce35169fd2493590d8371919161a7fb2e28e322863448b9a87.mp3']
            },
            {
              text: ['Unless the dealer has a five of six showing.'],
              type: 'BodyAnimation',
              sha256: [],
              animation: '',
              audio_urls: []
            }
          ],
          settings: {
            voice: true,
            animation: true
          }
        }
      }
    }
  end

  let(:params_speech_another_read_question) do
    {
      question: {
        narrator: {
          blocks: [
            {
              text: ['Farewell.', 'Mind yourself.'],
              type: 'Speech',
              sha256: %w[52ea67359dfa70ce35169fd2493590d8371919161a7fb2e28e322863448b9a87 7bffc2b191a07860fbcaae942775be40389b953b290aa774dbeabf57b57ba59d],
              animation: '',
              audio_urls: ['/rails/active_storage/blobs/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaEpJaWsxTmpKbE5UZ3dOaTFqTXprM0xUUm1PRGd0T0dGaE1TMDNZV1V6WXpoaE9UTTFZVGdHT2daRlZBPT0iLCJleHAiOm51bGwsInB1ciI6ImJsb2JfaWQifX0=--7e7f58df7135dc8738895a6aab5373c2595cdddf/52ea67359dfa70ce35169fd2493590d8371919161a7fb2e28e322863448b9a87.mp3', '/rails/active_storage/blobs/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaEpJaWt3WWpnNFpEUTVOQzFsTlRBMExUUmxaV1l0T1RNNE1TMWlZbVprWkRKaE4yRTJOalFHT2daRlZBPT0iLCJleHAiOm51bGwsInB1ciI6ImJsb2JfaWQifX0=--eb8a91e9b042434f6142608b388efe99b5a266d7/7bffc2b191a07860fbcaae942775be40389b953b290aa774dbeabf57b57ba59d.mp3']
            },
            {
              text: [],
              type: 'BodyAnimation',
              sha256: [],
              animation: [],
              audio_urls: []
            },
            {
              text: ["That chip of yours, I wouldn't wager it on Blackjack...Unless the dealer has a five of six showing."],
              type: 'ReadQuestion',
              sha256: [],
              animation: '',
              audio_urls: []
            }
          ],
          settings: {
            voice: true,
            animation: true
          }
        }
      }
    }
  end

  let(:params_another_reflection_another) do
    {
      question: {
        narrator: {
          blocks: [
            {
              text: [],
              type: 'BodyAnimation',
              sha256: [],
              animation: [],
              audio_urls: []
            },
            {
              question_id: 'ac97ab0d-4182-477b-8204-a347ca17012c',
              type: 'Reflection',
              reflections: [
                {
                  variable: 'var_multi_1',
                  value: 1,
                  payload: 'Answer 1',
                  text: [],
                  sha256: [],
                  audio_urls: []
                },
                {
                  variable: 'var_multi_2',
                  value: 2,
                  payload: 'Answer 2',
                  text: [
                    'Hello'
                  ],
                  sha256: [],
                  audio_urls: ['/rails/active_storage/blobs/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaEpJaWsxTmpKbE5UZ3dOaTFqTXprM0xUUm1PRGd0T0dGaE1TMDNZV1V6WXpoaE9UTTFZVGdHT2daRlZBPT0iLCJleHAiOm51bGwsInB1ciI6ImJsb2JfaWQifX0=--7e7f58df7135dc8738895a6aab5373c2595cdddf/52ea67359dfa70ce35169fd2493590d8371919161a7fb2e28e322863448b9a87.mp3', '/rails/active_storage/blobs/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaEpJaWt3WWpnNFpEUTVOQzFsTlRBMExUUmxaV1l0T1RNNE1TMWlZbVprWkRKaE4yRTJOalFHT2daRlZBPT0iLCJleHAiOm51bGwsInB1ciI6ImJsb2JfaWQifX0=--eb8a91e9b042434f6142608b388efe99b5a266d7/7bffc2b191a07860fbcaae942775be40389b953b290aa774dbeabf57b57ba59d.mp3']
                }
              ],
              "animation": 'rest',
              "position": {
                "posFrom": {
                  "x": 0,
                  "y": 0
                },
                "posTo": {
                  "x": 0,
                  "y": 0
                }
              }
            },
            {
              text: [],
              type: 'BodyAnimation',
              sha256: [],
              animation: [],
              audio_urls: []
            }
          ],
          settings: {
            voice: true,
            animation: true
          }
        }
      }
    }
  end

  let(:params) { params_turn_on }
  let(:intervention_id) { i_narrator_turn_off.id }
  let(:question_id) { q_narrator_turn_off.id }
  let(:narrator) { json_response['data']['attributes']['narrator'] }

  before do
    tts_instance = instance_double(Google::Cloud::TextToSpeech::V1::TextToSpeech::Client)
    speech_response_instance = Google::Cloud::TextToSpeech::V1::SynthesizeSpeechResponse::Fake.new

    allow(Google::Cloud::TextToSpeech).to receive(:text_to_speech).and_return(tts_instance)
    allow(tts_instance).to receive(:synthesize_speech).and_return(speech_response_instance)

    patch v1_intervention_question_path(intervention_id: intervention_id, id: question_id), headers: headers, params: params, as: :json
  end

  context 'switching narrator' do
    context 'turn on' do
      it { expect(response).to have_http_status(:ok) }

      it 'switched' do
        expect(narrator['settings']['voice']).to be true
      end
    end

    context 'turn off' do
      let(:params) { params_turn_off }

      it { expect(response).to have_http_status(:ok) }

      it 'switched' do
        expect(narrator['settings']['voice']).to be false
      end

      context 'when narrator has voice blocks' do
        let(:intervention_id) { i_narrator_blocks_types.id }
        let(:question_id) { q_narrator_blocks_types.id }

        it { expect(response).to have_http_status(:ok) }

        it 'switched' do
          expect(narrator['settings']['voice']).to be false
        end

        it 'removes voice blocks' do
          expect(narrator['blocks']).to eq([{
                                             'text' => [],
                                             'type' => 'BodyAnimation',
                                             'sha256' => [],
                                             'audio_urls' => []
                                           }])
        end
      end
    end
  end

  context 'was no block' do
    context 'params without block' do
      let(:intervention_id) { i_narrator_blocks_empty.id }
      let(:question_id) { q_narrator_blocks_empty.id }
      let(:params) { params_empty_block }

      it { expect(response).to have_http_status(:ok) }

      it 'persist empty' do
        expect(narrator['blocks']).to be_empty
      end

      context 'params with block' do
        let(:params) { params_speech }

        it { expect(response).to have_http_status(:ok) }

        it 'will contains blocks' do
          expect(narrator['blocks']).to be_present
        end

        it 'will have same blocks as from params' do
          expect(narrator['blocks'].size).to eq(params[:question][:narrator][:blocks].size)
        end
      end
    end

    context 'params with' do
      context 'first speech block, then another type' do
        let(:params) { params_speech_another }

        it 'will contains blocks' do
          expect(narrator['blocks']).to be_present
        end

        it 'will have same blocks as from params' do
          expect(narrator['blocks'].size).to eq(params[:question][:narrator][:blocks].size)
        end
      end

      context 'first speech block, another type, speech block' do
        let(:params) { params_speech_another_read_question }

        it 'will contains blocks' do
          expect(narrator['blocks']).to be_present
        end

        it 'will have same blocks as from params' do
          expect(narrator['blocks'].size).to eq(params[:question][:narrator][:blocks].size)
        end
      end

      context 'another type, then speech block' do
        let(:params) { params_another_speech }

        it 'will contains blocks' do
          expect(narrator['blocks']).to be_present
        end

        it 'will have same blocks as from params' do
          expect(narrator['blocks'].size).to eq(params[:question][:narrator][:blocks].size)
        end
      end

      context 'another type, then speech block, another' do
        let(:params) { params_another_reflection_another }

        it 'will contains blocks' do
          expect(narrator['blocks']).to be_present
        end

        it 'will have same blocks as from params' do
          expect(narrator['blocks'].size).to eq(params[:question][:narrator][:blocks].size)
        end
      end
    end
  end

  context 'was block' do
    let(:intervention_id) { i_narrator_block_one.id }
    let(:question_id) { q_narrator_block_one.id }

    context 'params without block' do
      let(:params) { params_empty_block }

      it 'does not contain blocks' do
        expect(narrator['blocks']).not_to be_present
      end
    end

    context 'params with' do
      context 'first speech block, then another type' do
        let(:params) { params_speech_another }

        it 'will contains blocks' do
          expect(narrator['blocks']).to be_present
        end

        it 'will have same blocks as from params' do
          expect(narrator['blocks'].size).to eq(params[:question][:narrator][:blocks].size)
        end
      end

      context 'first speech block, another type, speech block' do
        let(:params) { params_speech_another_read_question }

        it 'will contains blocks' do
          expect(narrator['blocks']).to be_present
        end

        it 'will have same blocks as from params' do
          expect(narrator['blocks'].size).to eq(params[:question][:narrator][:blocks].size)
        end
      end

      context 'another type, then speech block' do
        let(:params) { params_another_speech }

        it 'will contains blocks' do
          expect(narrator['blocks']).to be_present
        end

        it 'will have same blocks as from params' do
          expect(narrator['blocks'].size).to eq(params[:question][:narrator][:blocks].size)
        end
      end

      context 'another type, then speech block, another ' do
        let(:params) { params_another_reflection_another }

        it 'will contains blocks' do
          expect(narrator['blocks']).to be_present
        end

        it 'will have same blocks as from params' do
          expect(narrator['blocks'].size).to eq(params[:question][:narrator][:blocks].size)
        end
      end
    end
  end

  context 'was blocks, params with' do
    let(:intervention_id) { i_narrator_blocks_types.id }
    let(:question_id) { q_narrator_blocks_types.id }

    context 'less blocks' do
      let(:params) { params_speech }

      it 'will contains blocks' do
        expect(narrator['blocks']).to be_present
      end

      it 'will have same blocks as from params' do
        expect(narrator['blocks'].size).to eq(params[:question][:narrator][:blocks].size)
      end
    end

    context 'more blocks' do
      let(:params) { params_speech_another_read_question }

      it 'will contains blocks' do
        expect(narrator['blocks']).to be_present
      end

      it 'will have same blocks as from params' do
        expect(narrator['blocks'].size).to eq(params[:question][:narrator][:blocks].size)
      end
    end

    context 'equal blocks' do
      let(:params) { params_another_speech }

      it 'will contains blocks' do
        expect(narrator['blocks']).to be_present
      end

      it 'will have same blocks as from params' do
        expect(narrator['blocks'].size).to eq(params[:question][:narrator][:blocks].size)
      end
    end
  end
end
