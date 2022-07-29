# frozen_string_literal: true

Question_structure = Struct.new(:type, :settings, :narrator, :formulas, :body, :original_text)

def single
  settings = { 'image' => false, 'title' => true, 'video' => false, 'required' => true, 'subtitle' => true,
               'proceed_button' => true, 'narrator_skippable' => false }

  narrator = { 'blocks' =>
                   [{ 'text' => [Faker::Twitter.status(include_user: false)],
                      'type' => 'ReadQuestion',
                      'action' => 'NO_ACTION',
                      'sha256' => ['0004267f8d1a553971f1b7bd24c87fec50af8db465510f944e2a563e8da94f51'],
                      'animation' => 'rest',
                      'audio_urls' =>
                       ['/rails/active_storage/blobs/redirect/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaEpJaWxpWXpZeFpHRTBOeTFtTVdFM0xUUXpPV1V0T1RNellTMWxNR0ZoTW1ZNFlX
RmtZamdHT2daRlZBPT0iLCJleHAiOm51bGwsInB1ciI6ImJsb2JfaWQifX0=--44c697ccc3d8ddff5e918b7ddfa6e30453193a68/0004267f8d1a553971f1b7bd24c87fec50af8db465510f944e2a563e8
da94f51.mp3'],
                      'endPosition' => { 'x' => 600, 'y' => 550 } }],
               'settings' => { 'voice' => true, 'animation' => true } }

  formulas = [{ 'payload' => '', 'patterns' => [] }]

  body = { 'data' => [{ 'value' => '1', 'payload' => '' }], 'variable' => { 'name' => '' } }

  original_text = { 'title' => '', 'subtitle' => '', 'image_description' => '' }
  Question_structure.new('Question::Single', settings.to_json, narrator.to_json,
                         formulas.to_json, body.to_json, original_text.to_json)
end

def number
  settings = { 'image' => false, 'title' => true, 'video' => false, 'required' => true, 'subtitle' => true, 'narrator_skippable' => false }

  narrator = { 'blocks' =>
                [{ 'text' => [Faker::Twitter.status(include_user: false)],
                   'type' => 'ReadQuestion',
                   'action' => 'NO_ACTION',
                   'sha256' => ['13666aa9a466a975a7629fddc4a8a860586ddf9daf8733ab9de996bc98b35ae5'],
                   'animation' => 'rest',
                   'audio_urls' =>
                    ['/rails/active_storage/blobs/redirect/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaEpJaWt3TkdZME1qaGhaaTAyTnpWa0xUUmxNVEF0T1dOall5MDVaR015WWpCalpqbGha
V01HT2daRlZBPT0iLCJleHAiOm51bGwsInB1ciI6ImJsb2JfaWQifX0=--85cc748b9bc6181b1ecb1fa4dcf83a44b5c6cbeb/13666aa9a466a975a7629fddc4a8a860586ddf9daf8733ab9de996bc98b35
ae5.mp3'],
                   'endPosition' => { 'x' => 600, 'y' => 550 } }],
               'settings' => { 'voice' => true, 'animation' => true } }

  formulas = [{ 'payload' => '', 'patterns' => [] }]

  body = { 'data' => [{ 'payload' => '' }], 'variable' => { 'name' => '' } }

  original_text = { 'title' => '', 'subtitle' => '', 'image_description' => '' }

  Question_structure.new('Question::Number', settings.to_json, narrator.to_json,
                         formulas.to_json, body.to_json, original_text.to_json)
end

def final
  settings = { 'image' => false, 'title' => true, 'video' => false, 'subtitle' => true, 'narrator_skippable' => false }

  narrator = { 'blocks' =>
       [{ 'text' => [Faker::Twitter.status(include_user: false)],
          'type' => 'ReadQuestion',
          'action' => 'NO_ACTION',
          'sha256' => ['c7b076f0dae743ee666b40d925c86876266a4ae49d0a60fda3ec6523176cfa23'],
          'animation' => 'rest',
          'audio_urls' =>
           ['/rails/active_storage/blobs/redirect/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaEpJaWs0WlRRMFptRmtOaTFqWVRBM0xUUmtNMlF0T1dZeU9DMWlNR1l6T1dOa1l6bGlOVGNHT2daRl
ZBPT0iLCJleHAiOm51bGwsInB1ciI6ImJsb2JfaWQifX0=--5f9da50b666ad3f641990f56b7c363b58bfc195f/c7b076f0dae743ee666b40d925c86876266a4ae49d0a60fda3ec6523176cfa23.mp3'],
          'endPosition' => { 'x' => 600, 'y' => 550 } }],
               'settings' => { 'voice' => true, 'animation' => true } }

  formulas = [{ 'payload' => '', 'patterns' => [] }]

  body = { 'data' => [] }

  original_text = { 'title' => '', 'subtitle' => '', 'image_description' => '' }

  Question_structure.new('Question::Finish', settings.to_json, narrator.to_json,
                         formulas.to_json, body.to_json, original_text.to_json)
end
