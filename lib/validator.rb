# frozen_string_literal: true

require_relative 'validator/column_validator'
require_relative 'validator/label_validator'

##
# = Validator
# Groups the dataset row validators.
#
# == Reference
# - {docs/features/npc-calls.md}[docs/features/npc-calls.md]
##
module Validator
  module_function

  # Returns a new instance of every row validator, columns first so labels are checked on complete rows.
  def all
    [ColumnValidator.new, LabelValidator.new]
  end
end
