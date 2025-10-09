# frozen_string_literal: true

require 'json'
require_relative '../validation_error'
require_relative 'base_validator'

module Validator
  ##
  # = JsonSyntax
  # Validates that the output column contains valid JSON syntax.
  #
  # == Reference
  # - {docs/features/validation.md}[docs/features/validation.md]
  ##
  class JsonSyntax < BaseValidator
    # Validates that the row's output column contains valid JSON.
    #
    # Returns true if valid, raises ValidationError if invalid.
    def validate(row)
      output = row['output']

      if output.nil? || output.empty?
        raise ValidationError, "Missing output column"
      end

      JSON.parse(output)
      true
    rescue JSON::ParserError => e
      raise ValidationError, "Invalid JSON - #{e.message}"
    end
  end
end
