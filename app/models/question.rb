# frozen_string_literal: true

class Question < ApplicationRecord
  has_paper_trail
  extend DefaultValues
  include BodyInterface
  include Clone
  include FormulaInterface
  include BlockHelper
  include Translate

  UNIQUE_IN_SESSION = %w[Question::Name Question::ParticipantReport Question::ThirdParty Question::Phone
                         Question::HenryFordInitial].freeze
  CURRENT_VERSION = '2'

  belongs_to :question_group, inverse_of: :questions, touch: true, counter_cache: true
  has_many :answers, dependent: :destroy, inverse_of: :question

  attribute :narrator, :json, default: assign_default_values('narrator')
  attribute :position, :integer, default: 0
  attribute :formulas, :json, default: assign_default_values('formulas')
  attribute :body, :json, default: assign_default_values('body')
  attribute :original_text, :json, default: assign_default_values('original_text')
  attribute :duplicated, :boolean, default: false

  has_one_attached :image
  has_many_attached :speeches

  has_one :image_attachment, lambda {
                               where(name: 'image')
                             }, class_name: 'ActiveStorage::Attachment', as: :record, inverse_of: :record, dependent: false
  has_one :image_blob, through: :image_attachment, class_name: 'ActiveStorage::Blob', source: :blob

  validates :title, :type, presence: true
  validates :position, numericality: { greater_than_or_equal_to: 0 }
  validates :settings, json: { schema: lambda {
                                         Rails.root.join("#{json_schema_path}/settings.json").to_s
                                       }, message: lambda { |err|
                                                     err
                                                   } }
  validates :narrator, json: { schema: lambda {
                                         Rails.root.join("#{json_schema_path}/narrator.json").to_s
                                       }, message: lambda { |err|
                                                     err
                                                   } }
  validates :video_url, format: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true
  validates :formulas, json: { schema: lambda {
                                         Rails.root.join("#{json_schema_path}/formula.json").to_s
                                       }, message: lambda { |err|
                                                     err
                                                   } }
  validates :body, presence: true, json: { schema: lambda {
                                                     Rails.root.join("db/schema/#{self.class.name.underscore}/body.json").to_s
                                                   }, message: lambda { |err|
                                                                 err
                                                               } }
  validate :correct_variable_format

  delegate :session, to: :question_group
  delegate :ability_to_update_for?, to: :question_group

  after_create_commit :initialize_narrator
  before_destroy :decrement_usage_counters

  scope :tlfb, -> { where('type like ?', '%Tlfb%') }
  scope :without_tlfb, -> { where('type not like ?', '%Tlfb%') }
  default_scope { order(:position) }

  def subclass_name
    self.class.to_s.demodulize
  end

  def position_equal_or_higher
    @position_equal_or_higher ||= questionnaire.drop(current_position)
  end

  def position_lower
    @position_lower ||= questionnaire.slice(0...current_position)
  end

  def swap_name_mp3(name_audio, name_answer)
    blocks = narrator['blocks']
    blocks.map do |block|
      next block unless %w[Speech ReflectionFormula Reflection].include?(block['type'])

      name_audio_url = name_audio&.url.to_s

      name_text = name_answer.nil? ? 'name' : name_answer['name']

      "Question::Narrator::Block::#{block['type'].classify}".safe_constantize&.swap_name(block, name_audio_url, name_text)
    end
    self
  end

  def ability_to_clone?
    true
  end

  def prepare_to_display(_answers_var_values = nil)
    self
  end

  def variable_clone_prefix(_taken_variables) end

  def variable_with_clone_index(taken_variables, variable_base)
    index = 1
    new_variable = ''
    loop do
      new_variable = "clone#{index}_#{variable_base}"
      break unless taken_variables.include?(new_variable)

      index += 1
    end
    new_variable
  end

  def execute_narrator
    Narrator.new(self).execute
  end

  def remove_blocks_with_types(block_types_to_remove)
    narrator['blocks'] = narrator['blocks'].filter { |block| block_types_to_remove.exclude?(block['type']) }
  end

  def csv_header_names
    [body_variable['name']]
  end

  def translate_title(translator, source_language_name_short, destination_language_name_short)
    original_text['title'] = title
    new_title = translator.translate(title, source_language_name_short, destination_language_name_short)

    update!(title: new_title)
  end

  def translate_subtitle(translator, source_language_name_short, destination_language_name_short)
    original_text['subtitle'] = subtitle
    new_subtitle = translator.translate(subtitle, source_language_name_short, destination_language_name_short)

    update!(subtitle: new_subtitle)
  end

  def translate_image_description(translator, source_language_name_short, destination_language_name_short)
    return unless image.attached?

    original_description = image_blob.description
    original_text['image_description'] = original_description
    new_description = translator.translate(original_description, source_language_name_short, destination_language_name_short)
    image_blob.description = new_description

    image_blob.save!
  end

  def translate_body(_translator, _source_language_name_short, _destination_language_name_short) end

  def clear_audio
    narrator['blocks'].each do |block|
      block['sha256'] = []
      block['audio_urls'] = []
    end

    save!
  end

  # default implementation, returning no variables
  def question_variables
    []
  end

  def first_question?
    session.first_question == self
  end

  private

  def questionnaire
    @questionnaire = session.question_groups.includes([:questions], questions: %i[image_blob image_attachment]).map(&:questions).flatten
  end

  def current_position
    @current_position = questionnaire.map(&:id).find_index id
  end

  def initialize_narrator
    narrator['blocks'] << default_finish_screen_block if type == 'Question::Finish' && narrator['blocks'].empty?
    execute_narrator
  end

  def decrement_usage_counters
    Narrator.new(self).execute(destroy: true)
  end

  def json_schema_path
    @json_schema_path ||= 'db/schema/question'
  end

  def correct_variable_format
    return if body['data'].empty?

    question_variables.each do |variable|
      next if variable.blank? || special_variable?(variable) || /^([a-zA-Z]|[0-9]+[a-zA-Z_.]+)[a-zA-Z0-9_.\b]*$/.match?(variable)

      errors.add(:base, I18n.t('activerecord.errors.models.question_group.question_variable'))
    end
  end

  def special_variable?(_var)
    false
  end
end
