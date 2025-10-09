# frozen_string_literal: true

require_relative '../validation_error'
require_relative 'base_validator'

module Validator
  ##
  # = ExpectedPriceValidator
  # Validates that the item_expected_price column contains a valid price value.
  #
  # == Reference
  # - {docs/features/validation.md}[docs/features/validation.md]
  ##
  class ExpectedPriceValidator < BaseValidator
    # Validates that the row's item_expected_price column contains a valid price.
    #
    # Returns true if valid, raises ValidationError if invalid.
    def validate(row)
      price = row['item_expected_price']

      if price.nil? || price.to_s.empty?
        raise ValidationError, "Missing item_expected_price column"
      end

      price_value = price.to_f
      unless price_value > 0
        raise ValidationError, "Expected price must be greater than 0"
      end

      true
    end
  end
end
