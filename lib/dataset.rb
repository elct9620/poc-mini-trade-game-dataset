# frozen_string_literal: true

require 'csv'

##
# = Dataset
# Loads and parses CSV files for the mini trade game dataset.
# Provides enumerable interface for iterating through rows.
#
# == Reference
# - {docs/features/validation.md}[docs/features/validation.md]
##
class Dataset
  include Enumerable

  # Creates a new Dataset instance.
  #
  # file_path - The path to the CSV file to load.
  def initialize(file_path)
    @file_path = file_path
  end

  # Iterates through each row in the CSV file.
  #
  # Yields each row as a CSV::Row object.
  def each(&block)
    CSV.foreach(@file_path, headers: true, &block)
  end
end
