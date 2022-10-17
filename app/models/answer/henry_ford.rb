# frozen_string_literal: true

class Answer::HenryFord < Answer
  def csv_header_name(data)
    "henry_ford_health.#{data['var']}"
  end
end
