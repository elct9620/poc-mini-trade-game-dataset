# frozen_string_literal: true

module Validator
  ##
  # = BaseValidator
  # Base class for all validators. Each validator must implement the validate method.
  #
  # == Usage
  # class MyValidator < BaseValidator
  #   def validate(row)
  #     raise ValidationError, "Invalid data" unless row['field']
  #     true
  #   end
  # end
  #
  # == Reference
  # - {docs/features/validation.md}[docs/features/validation.md]
  ##
  class BaseValidator
    def validate(row)
      raise NotImplementedError, "Subclasses must implement the validate method"
    end
  end
end
