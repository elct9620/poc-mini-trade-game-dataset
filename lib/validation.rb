# frozen_string_literal: true

require_relative 'validation_error'

##
# = Validation
# Orchestrates the validation of dataset rows using multiple validators.
# Uses dependency injection to accept dataset and validators.
#
# == Reference
# - {docs/features/validation.md}[docs/features/validation.md]
##
class Validation
  # Creates a new Validation instance.
  #
  # dataset - The Dataset object to validate.
  # validators - Array of validator objects that respond to validate(row).
  def initialize(dataset, validators)
    @dataset = dataset
    @validators = validators
  end

  # Executes validation across all rows and validators.
  #
  # Returns an array of error messages. Empty array if all validations pass.
  def execute
    errors = []

    @dataset.each_with_index do |row, index|
      @validators.each do |validator|
        validator.validate(row)
      rescue ValidationError => e
        errors << "Row #{index + 2}: #{e.message}"
      end
    end

    errors
  end
end
