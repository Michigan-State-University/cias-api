# frozen_string_literal: true

class V1::Question::ShareService
  def self.call(user, question_ids, questions, researcher_ids)
    new(user, question_ids, questions, researcher_ids).call
  end

  def initialize(user, question_ids, questions, researcher_ids)
    @user = user
    @questions = questions
    @researchers = chosen_researchers(prepare_researchers(user), researcher_ids)
    @question_ids = question_ids
    @researcher_ids = researcher_ids
    @tlfb_type = questions.where('type like ?', '%Tlfb%').any?
  end

  attr_accessor :questions, :researchers, :tlfb_type
  attr_reader :question_ids, :researcher_ids, :user

  def call
    raise ActiveRecord::RecordNotFound unless proper_questions?(questions, question_ids) && proper_researchers?(researchers, researcher_ids)
    raise ActiveRecord::ActiveRecordError if inconsistent_question_group?

    researchers.each do |researcher|
      question_group = prepare_question_group(researcher, questions.first.question_group)
      question_group_questions = question_group.questions

      questions.each do |question|
        cloned = question.clone
        cloned.position = question_group_questions.last&.position.to_i + 1
        question_group_questions << cloned
      end
    end
  end

  def chosen_researchers(researchers, researcher_ids)
    researchers.where(id: researcher_ids)
  end

  def chosen_questions(ids)
    questions.where(id: ids)
  end

  private

  def inconsistent_question_group?
    question_groups_contains_tlfb_and_others_questions? || inconsistent_tlfb_group?
  end

  def question_groups_contains_tlfb_and_others_questions?
    questions.where('type not like ?', '%Tlfb%').any? && questions.where('type like ?', '%Tlfb%').any?
  end

  def inconsistent_tlfb_group?
    tlfb_questions = questions.where('type like ?', '%Tlfb%')
    tlfb_questions.any? && (tlfb_questions.count != 3 || tlfb_questions.pluck(:question_group_id).uniq.count != 1)
  end

  def prepare_question_group(researcher, question_group)
    intervention = question_group_intervention(question_group)
    create_new_question_group(researcher, intervention)
  end

  def question_group_intervention(question_group)
    question_group.session.intervention
  end

  def create_new_question_group(researcher, intervention)
    ActiveRecord::Base.transaction do
      new_intervention = Intervention.create!(
        name: "Copy of #{intervention.name} from #{user.full_name}",
        user: researcher
      )
      new_session = Session.create!(
        name: 'Copied Session',
        variable: 'copied_session',
        intervention: new_intervention
      )
      QuestionGroup.create!(
        title: 'Copied Slides',
        type: tlfb_type ? 'QuestionGroup::Tlfb' : 'QuestionGroup::Plain',
        session: new_session
      )
    end
  end

  def proper_questions?(questions, question_ids)
    question_ids && questions.size == question_ids.size
  end

  def proper_researchers?(researchers, researcher_ids)
    researcher_ids && researchers.size == researcher_ids.size
  end

  def prepare_researchers(user)
    all_researchers = User.researchers
    @researchers = if user.role?('researcher') && user.team_id.present?
                     all_researchers.from_team(user.team_id)
                   elsif user.role?('team_admin')
                     all_researchers.from_team(user.admins_team_ids)
                   elsif user.role?('admin')
                     all_researchers
                   else
                     User.none
                   end
  end
end
