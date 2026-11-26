# frozen_string_literal: true

require_relative '../validation_error'
require_relative 'base_validator'

module Validator
  ##
  # = LabelValidator
  # Validates that a row's labels take their allowed values and agree with each other.
  #
  # == Reference
  # - {docs/features/npc-calls.md}[docs/features/npc-calls.md]
  ##
  class LabelValidator < BaseValidator
    VALUES = {
      'relationship' => %w[hostile neutral friendly allied],
      'intent' => %w[offer haggle chat threat],
      'attitude' => %w[polite plain mild severe],
      'action' => %w[sell counter leave talk]
    }.freeze
    PRICED_ACTIONS = %w[sell counter].freeze

    # Validates the row's labels.
    #
    # Returns true if valid, raises ValidationError if invalid.
    def validate(row)
      VALUES.each do |column, values|
        raise ValidationError, "Invalid #{column} '#{row[column]}'" unless values.include?(row[column])
      end
      if (row['intent'] == 'offer') == blank?(row['offer'])
        raise ValidationError, "'offer' must be set only for intent 'offer'"
      end
      if PRICED_ACTIONS.include?(row['action']) == blank?(row['action_price'])
        raise ValidationError, "'action_price' must be set only for sell or counter"
      end
      if row['intent'] == 'threat' && row['attitude'] != 'severe'
        raise ValidationError, "Threat must have attitude 'severe'"
      end

      true
    end

    private

    def blank?(value)
      value.nil? || value.to_s.strip.empty?
    end
  end
end
