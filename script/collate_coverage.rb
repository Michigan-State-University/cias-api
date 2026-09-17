# frozen_string_literal: true

# Merges the per-shard SimpleCov resultsets produced by ci.yml's test matrix
# into a single coverage/coverage.json for SonarQube to import.
#
# Run from the repository root, after downloading the coverage-shard-* artifacts
# into ./coverage-shards:
#
#   ruby script/collate_coverage.rb
#
# Shards that failed, timed out or never started simply contribute nothing --
# whatever resultsets were uploaded are merged. A partial coverage figure is
# more useful than none, and the scan reports it as a real measurement.
#
# Exits 0 when there is nothing to collate so a run with no usable shards
# degrades to "scan without coverage" instead of failing the pipeline.

require 'fileutils'
require 'json'
require 'simplecov'
require_relative '../spec/sonar_json_formatter'

SHARD_DIR = 'coverage-shards'

resultsets = Dir["#{SHARD_DIR}/**/.resultset.json"]

if resultsets.empty?
  warn "No shard resultsets found under #{SHARD_DIR}/ -- nothing to collate."
  exit 0
end

warn "Collating #{resultsets.size} shard resultset(s):"
resultsets.each { |path| warn "  #{path}" }

# SimpleCov.root defaults to Dir.pwd. The shards recorded absolute paths from
# their own runners, which share this workspace path, so SonarJSONFormatter
# strips the same prefix here that it would have stripped in the spec run.
SimpleCov.collate(resultsets) do
  formatter SonarJSONFormatter
end

report = File.join(SimpleCov.coverage_path, 'coverage.json')
covered = File.exist?(report) ? JSON.parse(File.read(report))['coverage'] : {}

# SimpleCov.collate silently drops every file whose recorded absolute path does
# not exist here, and still writes a valid, empty report. SonarQube imports that
# as a measured 0%, which is indistinguishable from "the suite has no tests".
# The shards record the workspace they ran in, so this fires if collation runs
# from a different path than the specs did.
if covered.empty?
  warn 'Collated report covers no files: the shard paths do not resolve here. ' \
       'Shards and collation must run from the same workspace path. Discarding report.'
  FileUtils.rm_f(report)
  exit 0
end

warn "Collated coverage for #{covered.size} files."
