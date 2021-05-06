# frozen_string_literal: true

class Ability::ThirdParty < Ability::Base
  def definition
    super
    third_party if role?(class_name)
  end

  private

  def third_party
    can :read, GeneratedReport, id: GeneratedReport.for_third_party_user(user).pluck(:id),
                                report_for: 'third_party'
  end
end
