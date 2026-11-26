# frozen_string_literal: true

require 'json'
require_relative '../currency'
require_relative '../npc_schema'
require_relative 'simplified_characters'

class Evaluation
  ##
  # = Evaluation::Judge
  # Checks the extract and render replies of a row against the row. A metric is nil when it does not apply.
  #
  # == Reference
  # - {docs/tools/evaluation.md}[docs/tools/evaluation.md]
  ##
  module Judge
    KNOWN_CURRENCIES = (Currency::TRAIN + Currency::TEST).freeze

    module_function

    # Returns the extract checks: the reply's fields against the row's columns.
    def extract(row, reply)
      actual = parse_object(reply)
      offer = row['offer'].to_s.empty? ? nil : Integer(row['offer'])
      checks = {
        'intent_match' => actual&.dig('intent') == row['intent'],
        'attitude_match' => actual&.dig('attitude') == row['attitude'],
        'offer_match' => !actual.nil? && actual.key?('offer') && actual['offer'] == offer
      }
      { 'json_valid' => !actual.nil? }.merge(checks).merge('extract_match' => checks.values.all?)
    end

    # Returns the render checks: the reply's message against the row's price and the prompt's currency.
    def render(row, reply, currency)
      message = parse_object(reply)&.dig('message')
      text = message.is_a?(String) ? message : nil
      {
        'json_valid' => !parse_object(reply).nil?,
        'message_clean' => !text.nil? && NpcSchema::MESSAGE_PATTERN.match?(text),
        'message_traditional' => !text.nil? && text.each_char.none? { |char| SIMPLIFIED_CHARACTERS.key?(char) },
        'currency_foreign' => text.nil? || (KNOWN_CURRENCIES - [currency]).any? { |other| text.include?(other) },
        'price_said' => row['action_price'].to_s.empty? ? nil : !text.nil? && text.include?(row['action_price'].to_s),
        'currency_own' => row['message'].to_s.include?(row['currency'].to_s) ? !text.nil? && text.include?(currency) : nil
      }
    end

    def parse_object(reply)
      data = JSON.parse(reply.to_s)
      data.is_a?(Hash) ? data : nil
    rescue JSON::ParserError
      nil
    end

    private_class_method :parse_object
  end
end
