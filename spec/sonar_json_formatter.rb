# frozen_string_literal: true

require 'simplecov_json_formatter'

# SonarQube reads coverage through its SimpleCov importer, which needs two
# things SimpleCov does not produce by default:
#
#   1. The JSON formatter's coverage.json. The importer cannot parse the
#      .resultset.json written by SimpleCov 0.18+ and imports nothing.
#   2. Repo-relative paths. It resolves them against sonar.projectBaseDir,
#      which is /usr/src/project inside htd-cq's scanner container, so
#      SimpleCov's absolute host paths are all "cannot be found in filesystem".
#
# Lives outside spec/support/ because rails_helper auto-requires that whole
# directory after Rails boots, and script/collate_coverage.rb needs this class
# without loading Rails at all.
class SonarJSONFormatter < SimpleCov::Formatter::JSONFormatter
  private

  def format_result(result)
    super.tap do |hash|
      hash[:coverage] = hash[:coverage].transform_keys { |path| path.delete_prefix("#{SimpleCov.root}/") }
    end
  end
end
