# frozen_string_literal: true

require_relative '../validation_error'
require_relative 'base_validator'

module Validator
  ##
  # = ColumnValidator
  # Validates that a row fills its required columns and writes its numbers as positive integers.
  #
  # == Reference
  # - {docs/features/npc-calls.md}[docs/features/npc-calls.md]
  ##
  class ColumnValidator < BaseValidator
    REQUIRED = %w[id item_name relationship currency price input intent attitude action message].freeze
    NUMBERS = %w[price offer action_price].freeze

    # Validates the row's columns.
    #
    # Returns true if valid, raises ValidationError if invalid.
    def validate(row)
      missing = REQUIRED.find { |column| blank?(row[column]) }
      raise ValidationError, "Missing '#{missing}'" if missing

      malformed = NUMBERS.find { |column| !blank?(row[column]) && !positive_integer?(row[column]) }
      raise ValidationError, "'#{malformed}' must be a positive integer" if malformed

      if blank?(row['previous_player']) != blank?(row['previous_npc'])
        raise ValidationError, "'previous_player' and 'previous_npc' must be set together"
      end

      true
    end

    private

    def positive_integer?(value)
      value.to_s.match?(/\A[1-9]\d*\z/)
    end

    def blank?(value)
      value.nil? || value.to_s.strip.empty?
    end
  end
end
