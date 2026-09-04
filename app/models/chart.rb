# frozen_string_literal: true

class Chart < ApplicationRecord
  has_paper_trail
  extend DefaultValues
  include FormulaInterface
  include Clone

  belongs_to :dashboard_section
  has_many :chart_statistics, dependent: :destroy

  attribute :formula, :json, default: -> { assign_default_values('formula') }

  validates :formula, presence: true, json: { schema: lambda {
                                                        File.read(Rails.root.join("#{json_schema_path}/formula.json").to_s)
                                                      }, message: lambda { |err|
                                                                    err
                                                                  } }

  validate :validate_min_answered_variables
  validate :validate_positive_despite_missing_data
  validate :validate_reserved_label_unused

  enum :status, { draft: 'draft', data_collection: 'data_collection', published: 'published' }
  enum :chart_type, { bar_chart: 'bar_chart', pie_chart: 'pie_chart', percentage_bar_chart: 'percentage_bar_chart' }
  enum :interval_type, { monthly: 'monthly', quarterly: 'quarterly' } # only for bar charts
  default_scope { order(:position) }
  after_update_commit :status_change

  def integral_update(chart_params)
    return if published?

    assign_attributes(chart_params)
    save!
  end

  def status_change
    return unless saved_change_to_attribute?(:status)

    CreateChartStatisticsJob.perform_later(id) if status == 'data_collection'
  end

  def json_schema_path
    @json_schema_path ||= 'db/schema/chart'
  end

  def ability_to_clone?
    true
  end

  def chart_variables
    formula['payload'].scan(/\w+[.]\w+/)
  end

  # Distinct variables the formula payload depends on.
  # The calculator MUST be fresh and empty: Dentaku#dependencies only returns identifiers
  # absent from calculator memory, so a memoised/loaded calculator under-counts.
  # Returns nil for a payload Dentaku cannot parse (e.g. mid-typed `"HT2.phq1 +"`).
  def formula_variables
    Dentaku::Calculator.new(case_sensitive: true).dependencies(formula.to_h['payload']).uniq
  rescue Dentaku::Error
    nil
  end

  # Number of distinct variables the formula payload depends on (the `M` in "N out of M").
  def formula_variable_count
    formula_variables&.count
  end

  def validate_formula_variables(missing_vars, intervention)
    return [] if missing_vars.blank?

    available_vars = intervention_question_variables(intervention)

    missing_vars.reject do |var|
      var_name = var.split('.').last
      available_vars.include?(var_name)
    end
  end

  private

  # Deliberately loose: no `min <= formula_variable_count` ceiling and no Dentaku parse here.
  # The FE autosaves the payload on blur carrying the previous min, so a ceiling would turn
  # routine payload edits into a 422 (a silent revert for the user).
  def validate_min_answered_variables
    value = formula_setting('min_answered_variables')
    return if value.nil? || (value.is_a?(Integer) && value >= 0)

    errors.add(:formula, 'min_answered_variables must be an integer greater than or equal to 0')
  end

  # Replaced the numeric `positive_despite_missing_threshold` rescue before the feature ever
  # deployed. That key is no longer declared in `db/schema/chart/formula.json`, so a formula
  # still carrying it now fails the json-schema validation rather than being tolerated.
  def validate_positive_despite_missing_data
    value = formula_setting('positive_despite_missing_data')
    return if value.nil? || value == true || value == false

    errors.add(:formula, 'positive_despite_missing_data must be a boolean')
  end

  # The reserved "Invalid / Insufficient Data" label is stamped on rows by the validity
  # gate, and every aggregation buckets purely by label STRING - the pie groups by `label`
  # (pie_chart.rb:29-34) and both bar generators read only `patterns.first['label']` /
  # `default_pattern['label']`. A researcher case carrying that label would therefore merge
  # genuine screens with gate-excluded participants in one slice. Case-insensitive: a
  # near-duplicate would render as a second, confusingly similar category.
  #
  # Nil- AND type-tolerant by necessity: `db/schema/chart/formula.json` constrains no
  # pattern item (its `required` / `additionalProperties` sit inside the wrong object and
  # `items` is a draft-04 tuple, leaving `patterns[1..]` unvalidated) and `default_pattern`
  # is unconstrained. So `patterns` may not be an Array, an element may not be a Hash,
  # `default_pattern` may be absent or not a Hash, and `label` may be missing or non-String.
  #
  # Scope note: this covers collisions with the RESERVED label only. A pattern label
  # colliding with `default_pattern`'s own label is a different guarantee, already enforced
  # inside `V1::ChartStatistics::ValidityEvaluator#rescued?` - do not re-implement it here.
  def validate_reserved_label_unused
    return if formula_labels.none? { |label| reserved_label?(label) }

    errors.add(:formula,
               "label '#{ChartStatistic::INSUFFICIENT_DATA_LABEL}' is reserved for participants excluded " \
               'by the validity gate and cannot be used by a case or by the default category')
  end

  def formula_labels
    patterns = formula_setting('patterns')
    labels = patterns.is_a?(Array) ? patterns.map { |pattern| pattern['label'] if pattern.is_a?(Hash) } : []
    default_pattern = formula_setting('default_pattern')
    labels << (default_pattern['label'] if default_pattern.is_a?(Hash))
    labels.compact
  end

  def reserved_label?(label)
    label.is_a?(String) && label.casecmp?(ChartStatistic::INSUFFICIENT_DATA_LABEL)
  end

  def formula_setting(key)
    return nil unless formula.is_a?(Hash)

    formula[key]
  end

  def intervention_question_variables(intervention)
    # Keyed by intervention.id: a Chart instance can be called with different interventions.
    @intervention_question_variables ||= {}
    @intervention_question_variables[intervention.id] ||= ::Question
      .joins(question_group: :session)
      .where(sessions: { intervention_id: intervention.id })
      .flat_map(&:question_variables).compact.uniq
  end
end
