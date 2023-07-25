# frozen_string_literal: true

class Api::Documo
  def send_fax(fax_number, attachments, include_cover_page = false, fields = {}, logo = nil)
    Api::Documo::SendFax.call(fax_number, attachments, include_cover_page, fields, logo)
  end
end
