# frozen_string_literal: true

require 'json'
require_relative '../validation_error'
require_relative '../negotiation'
require_relative 'base_validator'

module Validator
  ##
  # = BargainingValidator
  # Validates a bargaining row: its state and extraction label columns, and that its reply
  # matches the outcome the game step computes from that state. Single-turn rows pass untouched.
  #
  # == Reference
  # - {docs/features/bargaining.md}[docs/features/bargaining.md]
  ##
  class BargainingValidator < BaseValidator
    REQUIRED_COLUMNS = %w[round patience counter_price intent rude].freeze
    NUMBER_COLUMNS = %w[round patience counter_price best_offer last_offer player_offer].freeze
    INTENTS = %w[offer haggle chat threat].freeze
    THREAT_FRIENDSHIP = -3

    # Validates a bargaining row; rows without a round are single-turn and pass.
    # Rows with an unknown rarity or relationship are left to RarityValidator and RelationshipValidator.
    #
    # Returns true if valid, raises ValidationError if invalid.
    def validate(row)
      return true if blank?(row['round'])
      return true unless Negotiation::PARAMETERS.key?(row['relationship_status'])
      return true unless ChatFormat::ASKING_RATIO.key?(row['item_rarity'])

      validate_columns(row)
      validate_state(row)
      validate_reply(row)
      true
    end

    private

    def validate_columns(row)
      REQUIRED_COLUMNS.each do |column|
        raise ValidationError, "Bargaining row is missing '#{column}'" if blank?(row[column])
      end
      raise ValidationError, "Invalid intent '#{row['intent']}'" unless INTENTS.include?(row['intent'])

      NUMBER_COLUMNS.each do |column|
        next if blank?(row[column]) || row[column].match?(/\A[1-9]\d*\z/)

        raise ValidationError, "'#{column}' must be a positive integer"
      end
      raise ValidationError, "'rude' must be none, mild, or severe" unless Negotiation::RUDE_LEVELS.include?(row['rude'])
      unless blank?(row['player_offer']) == (row['intent'] != 'offer')
        raise ValidationError, "'player_offer' must be set only for intent 'offer'"
      end
      if row['intent'] == 'offer' && !Negotiation.offer_stated?(row['input'], row['player_offer'])
        raise ValidationError, "'player_offer' #{row['player_offer']} is not a number in the player's message"
      end
      return if blank?(row['previous_input']) == blank?(row['previous_reply'])

      raise ValidationError, "'previous_input' and 'previous_reply' must be set together"
    end

    def validate_state(row)
      validate_patience(row)
      validate_counter(row)
      validate_offers(row)
    end

    def validate_patience(row)
      patience = row['patience'].to_i
      limit = Negotiation.patience_limit(row['relationship_status'])
      return if patience.between?(1, limit)

      raise ValidationError, "Patience #{patience} is outside 1 to #{limit}"
    end

    def validate_counter(row)
      prices = Negotiation.prices(row)
      counter = row['counter_price'].to_i
      unless counter.between?(prices[:floor], prices[:opening])
        raise ValidationError, "Counter price #{counter} is outside floor #{prices[:floor]} to opening #{prices[:opening]}"
      end
      return unless blank?(row['best_offer']) && counter != prices[:opening]

      raise ValidationError, "Counter price must be the opening #{prices[:opening]} before any offer"
    end

    def validate_offers(row)
      best = row['best_offer']
      last = row['last_offer']
      return if blank?(best) && blank?(last)
      return if !blank?(best) && !blank?(last) && best.to_i >= last.to_i

      raise ValidationError, "Offers must have best offer #{best.to_s.empty? ? 'none' : best} " \
                             "at least last offer #{last.to_s.empty? ? 'none' : last}"
    end

    def validate_reply(row)
      reply = JSON.parse(row['output'].to_s)
      return unless reply.is_a?(Hash)

      expected = Negotiation.turn(row)
      actual_price = %w[sell negotiate].include?(reply['action']) ? reply.dig('parameters', 'price') : nil
      unless reply['action'] == expected[:action] && actual_price == expected[:price]
        raise ValidationError, "Expected #{describe(expected[:action], expected[:price])} from the negotiation state, " \
                               "got #{describe(reply['action'], actual_price)}"
      end
      return unless row['intent'] == 'threat' && reply.dig('parameters', 'friendship_change') != THREAT_FRIENDSHIP

      raise ValidationError, 'Threat must change friendship by -3'
    rescue JSON::ParserError
      # JSON parsing errors are handled by JsonSyntax validator
      nil
    end

    def describe(action, price)
      price ? "#{action} at #{price}" : action.to_s
    end

    def blank?(value)
      value.nil? || value.to_s.strip.empty?
    end
  end
end
