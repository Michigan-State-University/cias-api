# frozen_string_literal: true

class V1::Intervention::ExportData
  attr_reader :intervention

  def self.call(intervention)
    new(intervention).call
  end

  def initialize(intervention)
    @intervention = intervention
  end

  def call
    V1::Export::InterventionSerializer.new(intervention).serializable_hash(include: '**')
  end

  def generate_file
    # require 'pry'; binding.pry
    file_path = ActiveStorage::Blob.service.send(:path_for, intervention.exported_data.key)
    file = File.open(file_path, 'wb')

    data = V1::Export::InterventionSerializer.new(intervention).serializable_hash(include: '**')
    file.write(JSON.pretty_generate(data))
    file.seek(-2, IO::SEEK_END)
    file.write ",\n"
    file.write('"sessions": [')

    intervention.sessions.find_each do |session|
      data = V1::Export::SessionSerializer.new(session).serializable_hash(include: '**')
      file.write(JSON.pretty_generate(data))
      file.seek(-1, IO::SEEK_END)
      file.write ",\n"
      file.write('"question_groups": [')
      question_groups_to_hash(session, file)
      file.seek(-1, IO::SEEK_END)
      file.write("]},")
    end
    file.seek(-1, IO::SEEK_END)
    file.write "]\n}"
    file.close
    file.unlink
  end

  def question_groups_to_hash(session, file)
    session.question_groups.find_each do |question_group|
      data = V1::Export::QuestionGroupSerializer.new(question_group).serializable_hash
      file.write(JSON.pretty_generate(data))
      file.seek(-1, IO::SEEK_END)
      file.write ",\n"
      file.write('"questions": [')
      questions_to_hash(question_group, file)
      file.seek(-1, IO::SEEK_END)
      file.write("]},")
    end
  end

  def questions_to_hash(question_group, file)
    question_group.questions.find_each do |question|
      data = V1::Export::QuestionSerializer.new(question).serializable_hash
      file.write(JSON.pretty_generate(data))
      file.write ","
    end
  end
end
