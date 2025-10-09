# frozen_string_literal: true

require_relative '../validation_error'
require_relative 'base_validator'

module Validator
  ##
  # = RarityValidator
  # Validates that the item_rarity column contains a valid rarity value.
  #
  # == Reference
  # - {docs/features/validation.md}[docs/features/validation.md]
  ##
  class RarityValidator < BaseValidator
    VALID_RARITIES = ['Common', 'Rare', 'Epic'].freeze

    # Validates that the row's item_rarity column contains a valid rarity.
    #
    # Returns true if valid, raises ValidationError if invalid.
    def validate(row)
      rarity = row['item_rarity']

      if rarity.nil? || rarity.empty?
        raise ValidationError, "Missing item_rarity column"
      end

      unless VALID_RARITIES.include?(rarity)
        raise ValidationError, "Invalid rarity '#{rarity}'. Must be one of: #{VALID_RARITIES.join(', ')}"
      end

      true
    end
  end
end
