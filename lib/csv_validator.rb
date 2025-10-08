# frozen_string_literal: true

require 'csv'
require 'json'

##
# # CsvValidator
# Validates CSV files containing training data for the mini trade game dataset.
# Ensures that the output column contains valid JSON with proper structure
# and game mechanics constraints.
#
# ## Reference
# - [docs/features/validation.md](docs/features/validation.md)
##
module CsvValidator
  VALID_ACTIONS = ['sell', 'refuse', 'negotiate', 'talk'].freeze
  FRIENDSHIP_RANGE = (-10..10).freeze

  # Validates a CSV file and returns an array of error messages.
  #
  # @param file_path [String] Path to the CSV file to validate
  # @return [Array<String>] Array of error messages, empty if valid
  def self.validate(file_path)
    errors = []

    CSV.foreach(file_path, headers: true).with_index(2) do |row, line_number|
      validate_row(row, line_number, errors)
    end

    errors
  end

  # Validates a single CSV row.
  #
  # @param row [CSV::Row] The CSV row to validate
  # @param line_number [Integer] The line number in the file
  # @param errors [Array<String>] Array to collect error messages
  def self.validate_row(row, line_number, errors)
    output = row['output']

    if output.nil? || output.empty?
      errors << "Row #{line_number}: Missing output column"
      return
    end

    validate_json(output, line_number, errors)
  end

  # Validates the JSON structure in the output column.
  #
  # @param output [String] The JSON string to validate
  # @param line_number [Integer] The line number in the file
  # @param errors [Array<String>] Array to collect error messages
  def self.validate_json(output, line_number, errors)
    data = JSON.parse(output)

    validate_action(data['action'], line_number, errors)
    validate_parameters(data, line_number, errors) if data['parameters']
  rescue JSON::ParserError => e
    errors << "Row #{line_number}: Invalid JSON - #{e.message}"
  end

  # Validates the action field.
  #
  # @param action [String] The action value to validate
  # @param line_number [Integer] The line number in the file
  # @param errors [Array<String>] Array to collect error messages
  def self.validate_action(action, line_number, errors)
    return if VALID_ACTIONS.include?(action)

    errors << "Row #{line_number}: Invalid action '#{action}'"
  end

  # Validates the parameters object.
  #
  # @param data [Hash] The parsed JSON data
  # @param line_number [Integer] The line number in the file
  # @param errors [Array<String>] Array to collect error messages
  def self.validate_parameters(data, line_number, errors)
    params = data['parameters']
    action = data['action']

    validate_price(action, params['price'], line_number, errors)
    validate_friendship(params['friendship_change'], line_number, errors)
  end

  # Validates the price parameter for sell/negotiate actions.
  #
  # @param action [String] The action type
  # @param price [Numeric] The price value to validate
  # @param line_number [Integer] The line number in the file
  # @param errors [Array<String>] Array to collect error messages
  def self.validate_price(action, price, line_number, errors)
    return unless ['sell', 'negotiate'].include?(action)
    return if price && price > 0

    errors << "Row #{line_number}: Price must be greater than 0 for action '#{action}'"
  end

  # Validates the friendship_change parameter.
  #
  # @param friendship [Integer] The friendship change value to validate
  # @param line_number [Integer] The line number in the file
  # @param errors [Array<String>] Array to collect error messages
  def self.validate_friendship(friendship, line_number, errors)
    return unless friendship
    return if FRIENDSHIP_RANGE.cover?(friendship)

    errors << "Row #{line_number}: Friendship value must be between -10 and 10"
  end
end
