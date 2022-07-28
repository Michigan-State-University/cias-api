# frozen_string_literal: true

Question_structure = Struct.new(:type, :settings, :narrator, :formulas, :body, :original_text)

def single
  settings = { 'image' => false, 'title' => true, 'video' => false, 'required' => true, 'subtitle' => true,
               'proceed_button' => true, 'narrator_skippable' => false }

  narrator = { 'blocks' =>
                   [{ 'text' => ['No'],
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

  body = { 'data' => [{ 'value' => '1', 'payload' => '' }], 'variable' => { 'name' => '' } }

  original_text = { 'title' => '', 'subtitle' => '', 'image_description' => '' }
  Question_structure.new('Question::Single', settings, narrator, [{ 'payload' => '', 'patterns' => [] }], body, original_text)
end
