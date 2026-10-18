# frozen_string_literal: true

require 'json'
require_relative 'chat_format'
require_relative 'bargaining_format'

##
# = Conversion
# Writes each single-turn row as one chat-format JSONL line for fine-tuning,
# and each bargaining row as an extraction line and a response line.
#
# == Reference
# - {docs/features/conversion.md}[docs/features/conversion.md]
# - {docs/features/bargaining.md}[docs/features/bargaining.md]
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
  # Returns the number of lines written.
  def execute
    @dataset.sum do |row|
      conversations(row).each { |messages| @io.puts JSON.generate({ 'messages' => messages }) }.size
    end
  end

  private

  def conversations(row)
    return [ChatFormat.conversation(row)] unless BargainingFormat.bargaining?(row)

    [BargainingFormat.extraction_conversation(row), BargainingFormat.response_conversation(row)]
  end
end
