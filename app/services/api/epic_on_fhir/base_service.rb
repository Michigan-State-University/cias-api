# frozen_string_literal: true

class Api::EpicOnFhir::BaseService
  protected

  def authentication
    @authentication ||= Api::EpicOnFhir::Authentication.call
  end
end
