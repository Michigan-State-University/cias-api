# frozen_string_literal: true

class Api::Documo
  def send_fax(fax_number, logo_url, pdf_file_url)
    Api::Documo::SendFax.call(fax_number, logo_url, pdf_file_url)
  end
end
