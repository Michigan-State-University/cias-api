# frozen_string_literal: true

namespace :cat_mh do
  desc 'Fill table base on information from documentation'

  task fill_cat_test_properties: :environment do

    diagnosis = AuxiliaryCatMhTestAttribute.create!(name: 'diagnosis', variable_type: 'string', range: "'negative' or 'positive'")
    confidence = AuxiliaryCatMhTestAttribute.create!(name: 'confidence', variable_type: 'number', range: '0-100')
    severity = AuxiliaryCatMhTestAttribute.create!(name: 'severity', variable_type: 'number', range: '0-100')
    category = AuxiliaryCatMhTestAttribute.create!(name: 'category', variable_type: 'string', range: 'description')
    precision = AuxiliaryCatMhTestAttribute.create!(name: 'precision', variable_type: 'number', range: '0-100')
    prob = AuxiliaryCatMhTestAttribute.create!(name: 'prob', variable_type: 'number', range: '0-1')
    percentile = AuxiliaryCatMhTestAttribute.create!(name: 'percentile', variable_type: 'number', range: '0-100')

    %w[dep anx p-dep p-anx cj-dep cj-anx].each do |type|
      test = AuxiliaryCatMhTestType.find_by(short_name: type)

      test.cat_mh_test_attributes << prob
      test.cat_mh_test_attributes << percentile
    end

    %w[m/hm p-m/hm ptsd ss cj-m/hm cj-sud cj-ss dep anx p-dep p-anx cj-dep cj-anx sdoh psy-s psy-c sud a/adhd].each do |type|
      test = AuxiliaryCatMhTestType.find_by(short_name: type)

      test.cat_mh_test_attributes << severity
      test.cat_mh_test_attributes << category
      test.cat_mh_test_attributes << precision
    end

    %w[mdd c-ssrs].each do |type|
      test = AuxiliaryCatMhTestType.find_by(short_name: type)

      test.cat_mh_test_attributes << diagnosis
    end

    test = AuxiliaryCatMhTestType.find_by(short_name: 'mdd')
    test.cat_mh_test_attributes << confidence
  end

  class AuxiliaryCatMhTestAttribute < ActiveRecord::Base
    self.table_name = 'cat_mh_test_attributes'

    has_many :cat_mh_variables, dependent: :destroy, class_name: 'AuxiliaryCatMhVariable', foreign_key: :cat_mh_test_attribute_id
    has_many :cat_mh_test_attributes, through: :cat_mh_variables, class_name: 'AuxiliaryCatMhTestAttribute', foreign_key: :cat_mh_test_attribute_id
  end

  class AuxiliaryCatMhVariable < ActiveRecord::Base
    self.table_name = 'cat_mh_variables'

    belongs_to :cat_mh_test_attribute, class_name: 'AuxiliaryCatMhTestAttribute', foreign_key: :cat_mh_test_attribute_id
    belongs_to :cat_mh_test_type, class_name: 'AuxiliaryCatMhTestType', foreign_key: :cat_mh_test_type_id
  end

  class AuxiliaryCatMhTestType < ActiveRecord::Base
    self.table_name = 'cat_mh_test_types'

    has_many :cat_mh_variables, dependent: :destroy, class_name: 'AuxiliaryCatMhVariable', foreign_key: :cat_mh_test_type_id
    has_many :cat_mh_test_attributes, through: :cat_mh_variables, class_name: 'AuxiliaryCatMhTestAttribute', foreign_key: :cat_mh_test_type_id
  end
end
