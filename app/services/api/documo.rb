# frozen_string_literal: true

class Api::Documo
  def send_faxes(fax_numbers, attachments, include_cover_page = false, fields = {}, logo = nil)
    Api::Documo::SendMultipleFaxes.call(fax_numbers, attachments, include_cover_page, fields, logo)
  end
end
