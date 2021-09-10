# frozen_string_literal: true

namespace :cat_mh do
  desc 'Fill table base on information from documentation'

  task fill_cat_test_properties: :environment do

    diagnosis = CatMhTestAttribute.create!(name: 'diagnosis', variable_type: 'string', range: "'negative' or 'positive'")
    confidence = CatMhTestAttribute.create!(name: 'confidence', variable_type: 'number', range: '0-100')
    severity = CatMhTestAttribute.create!(name: 'severity', variable_type: 'number', range: '0-100')
    category = CatMhTestAttribute.create!(name: 'category', variable_type: 'string', range: 'description')
    precision = CatMhTestAttribute.create!(name: 'precision', variable_type: 'number', range: '0-100')
    prob = CatMhTestAttribute.create!(name: 'prob', variable_type: 'number', range: '0-1')
    percentile = CatMhTestAttribute.create!(name: 'percentile', variable_type: 'number', range: '0-100')

    %w[dep anx p-dep p-anx cj-dep cj-anx].each do |type|
      test = CatMhTestType.find_by(short_name: type)

      test.cat_mh_test_attributes << prob
      test.cat_mh_test_attributes << percentile
    end

    %w[m/hm p-m/hm ptsd ss cj-m/hm cj-sud cj-ss dep anx p-dep p-anx cj-dep cj-anx sdoh psy-s psy-c sud a/adhd].each do |type|
      test = CatMhTestType.find_by(short_name: type)

      test.cat_mh_test_attributes << severity
      test.cat_mh_test_attributes << category
      test.cat_mh_test_attributes << precision
    end

    %w[mdd c-ssrs].each do |type|
      test = CatMhTestType.find_by(short_name: type)

      test.cat_mh_test_attributes << diagnosis
    end

    test = CatMhTestType.find_by(short_name: 'mdd')
    test.cat_mh_test_attributes << confidence
  end
end
