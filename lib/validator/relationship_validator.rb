# frozen_string_literal: true

require_relative '../validation_error'
require_relative 'base_validator'

module Validator
  ##
  # = RelationshipValidator
  # Validates that the relationship_status column contains a valid relationship value.
  #
  # == Reference
  # - {docs/features/validation.md}[docs/features/validation.md]
  ##
  class RelationshipValidator < BaseValidator
    VALID_RELATIONSHIPS = ['Hostile', 'Neutral', 'Friendly', 'Allied'].freeze

    # Validates that the row's relationship_status column contains a valid relationship.
    #
    # Returns true if valid, raises ValidationError if invalid.
    def validate(row)
      relationship = row['relationship_status']

      if relationship.nil? || relationship.empty?
        raise ValidationError, "Missing relationship_status column"
      end

      unless VALID_RELATIONSHIPS.include?(relationship)
        raise ValidationError, "Invalid relationship '#{relationship}'. Must be one of: #{VALID_RELATIONSHIPS.join(', ')}"
      end

      true
    end
  end
end
