# frozen_string_literal: true

Question_structure = Struct.new(:type, :title, :subtitle, :settings, :narrator, :formulas, :body, :original_text)

def single_q
  title = '<h2>What do you drink more usual?</h2>'
  subtitle = '<p>Select one product</p>'

  settings = { 'image': false, 'title': true, 'video': false, 'required': true, 'subtitle': true,
               'proceed_button': true, 'narrator_skippable': false }

  narrator = { 'blocks':
                   [{ 'text': ['Single'],
                      'type': 'ReadQuestion',
                      'action': 'NO_ACTION',
                      'sha256': ['0004267f8d1a553971f1b7bd24c87fec50af8db465510f944e2a563e8da94f51'],
                      'animation': 'rest',
                      'audio_urls':
                       [''],
                      'endPosition': { 'x': 600, 'y': 550 } }],
               'settings': { 'voice': true, 'animation': true } }

  formulas = [{ 'payload': '', 'patterns': [] }]

  body = { 'data': [{ 'value': '1', 'payload': '<p>Beer</p>' }, { 'value': '2', 'payload': '<p>Vodka</p>' }], 'variable': { 'name': 's' } }

  original_text = { 'title': '', 'subtitle': '', 'image_description': '' }
  Question_structure.new('Question::Single', title, subtitle, settings.to_json, narrator.to_json,
                         formulas.to_json, body.to_json, original_text.to_json)
end

def number_q
  title = '<h2>How much drinks did you drank last week?</h2>'
  subtitle = '<p>Enter a number of drinks</p>'

  settings = { 'image': false, 'title': true, 'video': false, 'required': true, 'subtitle': true, 'narrator_skippable': false }

  narrator = { 'blocks':
                [{ 'text': ['Number'],
                   'type': 'ReadQuestion',
                   'action': 'NO_ACTION',
                   'sha256': ['13666aa9a466a975a7629fddc4a8a860586ddf9daf8733ab9de996bc98b35ae5'],
                   'animation': 'rest',
                   'audio_urls':
                    [''],
                   'endPosition': { 'x': 600, 'y': 550 } }],
               'settings': { 'voice': true, 'animation': true } }

  formulas = [{ 'payload': '', 'patterns': [] }]

  body = { 'data': [{ 'value': '1', 'payload': '<p>Enter text here...</p>' }], 'variable': { 'name': 'n' } }

  original_text = { 'title': '', 'subtitle': '', 'image_description': '' }

  Question_structure.new('Question::Number', title, subtitle, settings.to_json, narrator.to_json,
                         formulas.to_json, body.to_json, original_text.to_json)
end

def date_q
  title = '<h2>When did you had last drink?</h2>'
  subtitle = '<p>Select a date of incident</p>'

  settings = { 'image': false, 'title': true, 'video': false, 'required': true, 'subtitle': true, 'narrator_skippable': false }

  narrator = { 'blocks':
       [{ 'text': ['Date'],
          'type': 'ReadQuestion',
          'action': 'NO_ACTION',
          'sha256': ['5b90b52baf4f794327162dd801834ecc1991a7f93801223c3f20ffa0fa501633'],
          'animation': 'rest',
          'audio_urls':
           [''],
          'endPosition': { 'x': 600, 'y': 550 } }],
               'settings': { 'voice': true, 'animation': true } }

  formulas = [{ 'payload': '', 'patterns': [] }]

  body = { 'data': [{ 'payload': '' }], 'variable': { 'name': 'd' } }

  original_text = { 'title': '', 'subtitle': '', 'image_description': '' }

  Question_structure.new('Question::Date', title, subtitle, settings.to_json, narrator.to_json,
                         formulas.to_json, body.to_json, original_text.to_json)
end

def multi_q
  title = "<h2>Did you have these symptoms this week?</h2>"
  subtitle = "<p>Select all symptoms</p>"

  settings = {"image":false, "title":true, "video":false, "required":true, "subtitle":true, "narrator_skippable":false}

  narrator = {"blocks":
     [{"text":["Select all symptoms"],
       "type":"ReadQuestion",
       "action":"NO_ACTION",
       "sha256":["13102d9211d0ae05caa9dff55afbb0715c15500b8d78a9ad53acb571af088764"],
       "animation":"rest",
       "audio_urls":
         [""],
       "endPosition":{"x":600, "y":550}}],
   "settings":{"voice":true, "animation":true}}

  formulas = [{"payload":"", "patterns":[]}]

  body = {"data":
            [{"payload":"<p>Emotional instability</p>", "variable":{"name":"m1", "value":"1"}},
             {"payload":"<p>Lack of food consumption</p>", "variable":{"name":"m2", "value":"2"}},
             {"payload":"<p>Isolation</p>", "variable":{"name":"m3", "value":"3"}}]}


  original_text = {"title":"", "subtitle":"", "image_description":""}
  Question_structure.new('Question::Multiple', title, subtitle, settings.to_json, narrator.to_json,
                         formulas.to_json, body.to_json, original_text.to_json)
end

def free_q
  title = "<h2>How is your feeling today?</h2>"
  subtitle = "<p>Write a response</p>"

  settings = {"image"=>false, "title"=>true, "video"=>false, "required"=>true, "subtitle"=>true, "text_limit"=>250, "narrator_skippable"=>false}

  narrator = {"blocks"=>
       [{"text"=>["Your feedback"],
         "type"=>"ReadQuestion",
         "action"=>"NO_ACTION",
         "sha256"=>["28905bbdf618e7ea58374dc0233a81f32aea13cd0b1c6063c352a07b5e6c6aa2"],
         "animation"=>"rest",
         "audio_urls"=>
           [""],
         "endPosition"=>{"x"=>600, "y"=>550}}],
     "settings"=>{"voice"=>true, "animation"=>true}}

  formulas = [{"payload"=>"", "patterns"=>[]}]

  body = {"data"=>[{"payload"=>""}], "variable"=>{"name"=>""}}

  original_text = {"title"=>"", "subtitle"=>"", "image_description"=>""}

  Question_structure.new('Question::FreeResponse', title, subtitle, settings.to_json, narrator.to_json,
                         formulas.to_json, body.to_json, original_text.to_json)
end

def currency_q
  title = "<h2>How much money do you spend on alcohol monthly?</h2>"
  subtitle = "<p>Give estimated value spent on alcohol</p>"

  settings = {"image"=>false, "title"=>true, "video"=>false, "required"=>true, "subtitle"=>true, "narrator_skippable"=>false}

  narrator = {"blocks"=>
       [{"text"=>["Give estimated value spent on alcohol"],
         "type"=>"ReadQuestion",
         "action"=>"NO_ACTION",
         "sha256"=>["4cd0ac1d2a003a6fd8367e2077c6135756b5bce1a6ae640a69541e8430314cfa"],
         "animation"=>"rest",
         "audio_urls"=>
           ["/rails/active_storage/blobs/redirect/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaEpJaWswT1dGak0yUmpOQzFpTkdZd0xUUmxPV1V0WVdVNU1TMWhNamhrTUdKak9URmxZekVHT2daRlZBPT0iLCJleHAiOm51bGwsInB1ciI6ImJsb2JfaWQifX0=--450cc024484d67098c991059325e6f074bd91816/4cd0ac1d2a003a6fd8367e2077c6135756b5bce1a6ae640a69541e8430314cfa.mp3"],
         "endPosition"=>{"x"=>600, "y"=>550}}],
     "settings"=>{"voice"=>true, "animation"=>true}}

  formulas = [{"payload"=>"", "patterns"=>[]}]

  body = {"data"=>[{"payload"=>""}], "variable"=>{"name"=>"c"}}

  original_text = {"title"=>"", "subtitle"=>"", "image_description"=>""}

  Question_structure.new('Question::Currency', title, subtitle, settings.to_json, narrator.to_json,
                         formulas.to_json, body.to_json, original_text.to_json)
end
