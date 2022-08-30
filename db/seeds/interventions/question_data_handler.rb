# frozen_string_literal: true

Question_structure = Struct.new(:type, :title, :subtitle, :settings, :narrator, :formulas, :body, :original_text)

def single_q
  title = '<h2>What do you drink more usual?</h2>'
  subtitle = '<p>Select one product</p>'

  settings = { image: false, title: true, video: false, required: true, subtitle: true,
               proceed_button: true, narrator_skippable: false }

  narrator = { blocks:
                 [{ text: ['Single'],
                    type: '',
                    action: '',
                    sha256: [''],
                    animation: 'rest',
                    audio_urls: [''],
                    endPosition: { x: 600, y: 550 } }],
               settings: { voice: true, animation: true } }

  formulas = [{ payload: '', patterns: [] }]

  body = { data: [{ value: '1', payload: '<p>Beer</p>' }, { value: '2', payload: '<p>Vodka</p>' }], variable: { name: 's' } }

  original_text = { title: '', subtitle: '', image_description: '' }
  Question_structure.new('Question::Single', title, subtitle, settings.to_json, narrator.to_json,
                         formulas.to_json, body.to_json, original_text.to_json)
end

def number_q
  title = '<h2>How much drinks did you drank last week?</h2>'
  subtitle = '<p>Enter a number of drinks</p>'

  settings = { image: false, title: true, video: false, required: true, subtitle: true, narrator_skippable: false }

  narrator = { blocks:
                 [{ text: ['Number'],
                    type: '',
                    action: '',
                    sha256: [''],
                    animation: '',
                    audio_urls: [''],
                    endPosition: { x: 600, y: 550 } }],
               settings: { voice: true, animation: true } }

  formulas = [{ payload: '', patterns: [] }]

  body = { data: [{ value: '1', payload: '<p>Enter text here...</p>' }], variable: { name: 'n' } }

  original_text = { title: '', subtitle: '', image_description: '' }

  Question_structure.new('Question::Number', title, subtitle, settings.to_json, narrator.to_json,
                         formulas.to_json, body.to_json, original_text.to_json)
end

def date_q
  title = '<h2>When did you had last drink?</h2>'
  subtitle = '<p>Select a date of incident</p>'

  settings = { image: false, title: true, video: false, required: true, subtitle: true, narrator_skippable: false }

  narrator = { blocks:
                 [{ text: ['Date'],
                    type: '',
                    action: '',
                    sha256: [''],
                    animation: '',
                    audio_urls: [''],
                    endPosition: { x: 600, y: 550 } }],
               settings: { voice: true, animation: true } }

  formulas = [{ payload: '', patterns: [] }]

  body = { data: [{ payload: '' }], variable: { name: 'd' } }

  original_text = { title: '', subtitle: '', image_description: '' }

  Question_structure.new('Question::Date', title, subtitle, settings.to_json, narrator.to_json,
                         formulas.to_json, body.to_json, original_text.to_json)
end

def multi_q
  title = '<h2>Did you have these symptoms this week?</h2>'
  subtitle = '<p>Select all symptoms</p>'

  settings = { image: false, title: true, video: false, required: true, subtitle: true, narrator_skippable: false }

  narrator = { blocks:
                 [{ text: ['Select all symptoms'],
                    type: '',
                    action: '',
                    sha256: [''],
                    animation: '',
                    audio_urls: [''],
                    endPosition: { x: 600, y: 550 } }],
               settings: { voice: true, animation: true } }

  formulas = [{ payload: '', patterns: [] }]

  body = { data:
             [{ payload: '<p>Emotional instability</p>', variable: { name: 'm1', value: '1' } },
              { payload: '<p>Lack of food consumption</p>', variable: { name: 'm2', value: '2' } },
              { payload: '<p>Isolation</p>', variable: { name: 'm3', value: '3' } }] }

  original_text = { title: '', subtitle: '', image_description: '' }
  Question_structure.new('Question::Multiple', title, subtitle, settings.to_json, narrator.to_json,
                         formulas.to_json, body.to_json, original_text.to_json)
end

def free_q
  title = '<h2>How is your feeling today?</h2>'
  subtitle = '<p>Write a response</p>'

  settings = { image: false, title: true, video: false, required: true, subtitle: true, text_limit: 250, narrator_skippable: false }

  narrator = { blocks:
                 [{ text: ['Your feedback'],
                    type: '',
                    action: '',
                    sha256: [''],
                    animation: '',
                    audio_urls: [''],
                    endPosition: { x: 600, y: 550 } }],
               settings: { voice: true, animation: true } }

  formulas = [{ payload: '', patterns: [] }]

  body = { data: [{ payload: '' }], variable: { name: '' } }

  original_text = { title: '', subtitle: '', image_description: '' }

  Question_structure.new('Question::FreeResponse', title, subtitle, settings.to_json, narrator.to_json,
                         formulas.to_json, body.to_json, original_text.to_json)
end

def currency_q
  title = '<h2>How much money do you spend on alcohol monthly?</h2>'
  subtitle = '<p>Give estimated value spent on alcohol</p>'

  settings = { image: false, title: true, video: false, required: true, subtitle: true, narrator_skippable: false }

  narrator = { blocks:
                 [{ text: ['Give estimated value spent on alcohol'],
                    type: '',
                    action: '',
                    sha256: [''],
                    animation: '',
                    audio_urls: [''],
                    endPosition: { x: 600, y: 550 } }],
               settings: { voice: true, animation: true } }

  formulas = [{ payload: '', patterns: [] }]

  body = { data: [{ payload: '' }], variable: { name: 'c' } }

  original_text = { title: '', subtitle: '', image_description: '' }

  Question_structure.new('Question::Currency', title, subtitle, settings.to_json, narrator.to_json,
                         formulas.to_json, body.to_json, original_text.to_json)
end
