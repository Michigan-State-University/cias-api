# frozen_string_literal: true

Question_structure = Struct.new(:type, :title, :subtitle, :settings, :narrator, :formulas, :body, :original_text)

def single_q
  title = '<b>What do you drink more usual?</b>'
  subtitle = 'Select one product'

  settings = { 'image' => false, 'title' => true, 'video' => false, 'required' => true, 'subtitle' => true,
               'proceed_button' => true, 'narrator_skippable' => false }

  narrator = { 'blocks' =>
                   [{ 'text' => ['Single'],
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

  body = { 'data' => [{ 'value' => '1', 'payload' => 'Beer' }, { 'value' => '2', 'payload' => 'Vodka' }], 'variable' => { 'name' => 's' } }

  original_text = { 'title' => '', 'subtitle' => '', 'image_description' => '' }
  Question_structure.new('Question::Single', title, subtitle, settings.to_json, narrator.to_json,
                         formulas.to_json, body.to_json, original_text.to_json)
end

def number_q
  title = '<b>How much drinks did you drank last week?</b>'
  subtitle = 'Enter a number of drinks'

  settings = { 'image' => false, 'title' => true, 'video' => false, 'required' => true, 'subtitle' => true, 'narrator_skippable' => false }

  narrator = { 'blocks' =>
                [{ 'text' => ['Number'],
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

  body = { 'data' => [{ 'value' => '1', 'payload' => 'Enter text here...>' }], 'variable' => { 'name' => 'n' } }

  original_text = { 'title' => '', 'subtitle' => '', 'image_description' => '' }

  Question_structure.new('Question::Number', title, subtitle, settings.to_json, narrator.to_json,
                         formulas.to_json, body.to_json, original_text.to_json)
end

def date_q
  title = '<b>When did you had last drink?</b>'
  subtitle = 'Select a date of incident'

  settings = { 'image' => false, 'title' => true, 'video' => false, 'required' => true, 'subtitle' => true, 'narrator_skippable' => false }

  narrator = { 'blocks' =>
       [{ 'text' => ['Date'],
          'type' => 'ReadQuestion',
          'action' => 'NO_ACTION',
          'sha256' => ['5b90b52baf4f794327162dd801834ecc1991a7f93801223c3f20ffa0fa501633'],
          'animation' => 'rest',
          'audio_urls' =>
           ['/rails/active_storage/blobs/redirect/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaEpJaWt3T1RBMVlXSTJZeTFsTVRjekxUUTJObUl0WW1Rek5pMWpaRFF6TUdVeU56azRZV0lHT2daRl
ZBPT0iLCJleHAiOm51bGwsInB1ciI6ImJsb2JfaWQifX0=--93edf7a2e2bab85464719a11305c4786c750cca2/5b90b52baf4f794327162dd801834ecc1991a7f93801223c3f20ffa0fa501633.mp3'],
          'endPosition' => { 'x' => 600, 'y' => 550 } }],
               'settings' => { 'voice' => true, 'animation' => true } }

  formulas = [{ 'payload' => '', 'patterns' => [] }]

  body = { 'data' => [{ 'payload' => '' }], 'variable' => { 'name' => 'd' } }

  original_text = { 'title' => '', 'subtitle' => '', 'image_description' => '' }

  Question_structure.new('Question::Date', title, subtitle, settings.to_json, narrator.to_json,
                         formulas.to_json, body.to_json, original_text.to_json)
end

def final_q
  title = '<b>Thanks for your input!</b>'
  subtitle = 'Final screen'

  settings = { 'image' => false, 'title' => true, 'video' => false, 'subtitle' => true, 'narrator_skippable' => false }

  narrator = { 'blocks' =>
       [{ 'text' => ['Final'],
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

  Question_structure.new('Question::Finish', title, subtitle, settings.to_json, narrator.to_json,
                         formulas.to_json, body.to_json, original_text.to_json)
end
