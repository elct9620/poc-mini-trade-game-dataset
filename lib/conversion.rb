# frozen_string_literal: true

require 'json'
require_relative 'chat_format'

##
# = Conversion
# Writes each dataset row as one chat-format JSONL line for fine-tuning.
#
# == Reference
# - {docs/features/conversion.md}[docs/features/conversion.md]
##
class Conversion
  # Creates a new Conversion instance.
  #
  # dataset - The Dataset object to convert.
  # io - The IO object receiving JSONL lines.
  def initialize(dataset, io)
    @dataset = dataset
    @io = io
  end

  # Executes the conversion.
  #
  # Returns the number of rows written.
  def execute
    written = 0
    @dataset.each do |row|
      @io.puts JSON.generate({ 'messages' => ChatFormat.conversation(row) })
      written += 1
    end
    written
  end
end
