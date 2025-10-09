# frozen_string_literal: true

require 'json'
require_relative '../validation_error'
require_relative 'base_validator'

module Validator
  ##
  # = PriceRangeValidator
  # Validates that the price in the output JSON follows the rarity and relationship rules.
  #
  # == Reference
  # - {docs/features/validation.md}[docs/features/validation.md]
  ##
  class PriceRangeValidator < BaseValidator
    # Validates that the price follows the rarity and relationship constraints.
    #
    # Returns true if valid, raises ValidationError if invalid.
    def validate(row)
      output = row['output']
      return true if output.nil? || output.empty?

      data = JSON.parse(output)
      action = data['action']

      # Only validate price for sell/negotiate actions
      return true unless ['sell', 'negotiate'].include?(action)

      price = data.dig('parameters', 'price')
      return true unless price

      expected_price = row['item_expected_price'].to_f
      rarity = row['item_rarity']
      relationship = row['relationship_status']

      validate_price_range(price, expected_price, rarity, relationship)

      true
    rescue JSON::ParserError
      # JSON parsing errors are handled by JsonSyntax validator
      true
    end

    private

    # Validates the price against the minimum price condition.
    def validate_price_range(price, expected_price, rarity, relationship)
      case rarity
      when 'Common'
        validate_common_price(price, expected_price, relationship)
      when 'Rare'
        validate_rare_price(price, expected_price, relationship)
      when 'Epic'
        validate_epic_price(price, expected_price, relationship)
      end
    end

    # Validates price for Common rarity items.
    def validate_common_price(price, expected_price, relationship)
      case relationship
      when 'Hostile'
        return if price > expected_price * 1.2
      when 'Neutral'
        return if price >= expected_price
      when 'Friendly'
        return if price >= expected_price * 0.8
      when 'Allied'
        return if price > 0
      end

      raise ValidationError, "Price #{price} is below the minimum allowed price for Common rarity with #{relationship} relationship"
    end

    # Validates price for Rare rarity items.
    def validate_rare_price(price, expected_price, relationship)
      case relationship
      when 'Hostile'
        return if price >= expected_price * 1.5
      when 'Neutral'
        return if price >= expected_price
      when 'Friendly'
        return if price >= expected_price
      when 'Allied'
        return if price > 0
      end

      raise ValidationError, "Price #{price} is below the minimum allowed price for Rare rarity with #{relationship} relationship"
    end

    # Validates price for Epic rarity items.
    def validate_epic_price(price, expected_price, relationship)
      case relationship
      when 'Hostile'
        return if price >= expected_price * 2.0
      when 'Neutral'
        return if price >= expected_price * 1.2
      when 'Friendly'
        return if price >= expected_price
      when 'Allied'
        return if price > 0
      end

      raise ValidationError, "Price #{price} is below the minimum allowed price for Epic rarity with #{relationship} relationship"
    end
  end
end
