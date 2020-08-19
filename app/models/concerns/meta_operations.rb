# frozen_string_literal: true

module MetaOperations
  extend ActiveSupport::Concern

  included do
    def de_constantize_modulize_name
      ctx_name = model_name.name
      deconst_ctx_name = ctx_name.deconstantize

      deconst_ctx_name.empty? ? ctx_name : deconst_ctx_name
    end
  end
end
