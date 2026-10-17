# frozen_string_literal: true

require_relative 'validator/json_syntax'
require_relative 'validator/schema_validator'
require_relative 'validator/rarity_validator'
require_relative 'validator/relationship_validator'
require_relative 'validator/expected_price_validator'
require_relative 'validator/price_range_validator'

##
# = Validator
# Groups the dataset rule validators.
# Validation and evaluation share the same set so a model output is judged by the dataset rules.
#
# == Reference
# - {docs/features/validation.md}[docs/features/validation.md]
# - {docs/features/evaluation.md}[docs/features/evaluation.md]
##
module Validator
  module_function

  # Returns a new instance of every rule validator.
  def all
    [
      RarityValidator.new,
      RelationshipValidator.new,
      ExpectedPriceValidator.new,
      JsonSyntax.new,
      SchemaValidator.new,
      PriceRangeValidator.new
    ]
  end
end
