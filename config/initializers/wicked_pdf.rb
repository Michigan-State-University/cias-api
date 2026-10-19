# frozen_string_literal: true

# WickedPDF Global Configuration
#
# Use this to set up shared configuration options for your entire application.
# Any of the configuration options shown here can also be applied to single
# models by passing arguments to the `render :pdf` call.
#
# To learn more, check out the README:
#
# https://github.com/mileszs/wicked_pdf/blob/master/README.md

WickedPdf.config ||= {}
WickedPdf.config.merge!({
                          # Path to the wkhtmltopdf executable. Set only in the Docker image,
                          # where the wkhtmltopdf-heroku binary can't run; elsewhere the key is
                          # dropped by .compact and the gem's binary stays in effect.
                          exe_path: ENV.fetch('WKHTMLTOPDF_PATH', nil)

                          # Layout file to be used for all PDFs
                          # (but can be overridden in `render :pdf` calls)
                          # layout: 'pdf.html',

                          # Using wkhtmltopdf without an X server can be achieved by enabling the
                          # 'use_xvfb' flag. This will wrap all wkhtmltopdf commands around the
                          # 'xvfb-run' command, in order to simulate an X server.
                          #
                          # use_xvfb: true,
                        }.compact)
