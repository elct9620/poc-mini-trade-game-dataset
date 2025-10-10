# frozen_string_literal: true

require 'json'
require_relative '../validation_error'
require_relative 'base_validator'

module Validator
  ##
  # = SchemaValidator
  # Validates the JSON schema and business rules for the output column.
  # Ensures valid actions, price constraints, and friendship ranges.
  #
  # == Reference
  # - {docs/features/validation.md}[docs/features/validation.md]
  ##
  class SchemaValidator < BaseValidator
    VALID_ACTIONS = ['sell', 'refuse', 'negotiate', 'talk'].freeze
    FRIENDSHIP_RANGE = (-3..3).freeze

    # Validates the JSON structure and business rules.
    #
    # Returns true if valid, raises ValidationError if invalid.
    def validate(row)
      output = row['output']
      return true if output.nil? || output.empty?

      data = JSON.parse(output)

      validate_action(data['action'])
      validate_parameters(data) if data['parameters']

      true
    rescue JSON::ParserError
      # JSON parsing errors are handled by JsonSyntax validator
      true
    end

    private

    # Validates the action field.
    def validate_action(action)
      return if VALID_ACTIONS.include?(action)

      raise ValidationError, "Invalid action '#{action}'"
    end

    # Validates the parameters object.
    def validate_parameters(data)
      params = data['parameters']
      action = data['action']

      validate_price(action, params['price'])
      validate_friendship(params['friendship_change'])
    end

    # Validates the price parameter for sell/negotiate actions.
    def validate_price(action, price)
      return unless ['sell', 'negotiate'].include?(action)
      return if price && price > 0

      raise ValidationError, "Price must be greater than 0 for action '#{action}'"
    end

    # Validates the friendship_change parameter.
    def validate_friendship(friendship)
      return unless friendship
      return if FRIENDSHIP_RANGE.cover?(friendship)

      raise ValidationError, "Friendship value must be between -3 and 3"
    end
  end
end
