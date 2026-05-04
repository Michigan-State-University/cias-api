# frozen_string_literal: true

class BulkImportMailer < ApplicationMailer
  def bulk_import_result(researcher, intervention, result)
    @researcher = researcher
    @intervention = intervention
    @result = result

    mail(to: @researcher.email, subject: I18n.t('bulk_import_mailer.bulk_import_result.subject'))
  end

  def bulk_import_error(researcher, intervention)
    @researcher = researcher
    @intervention = intervention

    mail(to: @researcher.email, subject: I18n.t('bulk_import_mailer.bulk_import_error.subject'))
  end
end
