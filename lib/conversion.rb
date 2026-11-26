# frozen_string_literal: true

require 'json'
require_relative 'npc_prompt'
require_relative 'currency'
require_relative 'rebalancing'

##
# = Conversion
# Writes the extract and render samples of a split as chat-format JSONL for fine-tuning.
# The train split is rebalanced per call and uses train currencies; the test split keeps every row once
# and uses test currencies.
#
# == Reference
# - {docs/features/npc-calls.md}[docs/features/npc-calls.md]
##
class Conversion
  CALLS = {
    extract: ->(row) { "#{row['intent']}/#{row['attitude']}" },
    render: ->(row) { "#{row['action']}/#{NpcPrompt.emotion(row)}" }
  }.freeze
  SPLITS = { 'train' => Currency::TRAIN, 'test' => Currency::TEST }.freeze

  # Creates a new Conversion instance.
  #
  # dataset - The Dataset object to convert.
  # io - The IO object receiving JSONL lines.
  # split - 'train' or 'test'.
  def initialize(dataset, io, split:)
    @rows = dataset.map { |row| row.to_h }
    @io = io
    @split = split
    @currencies = SPLITS.fetch(split)
  end

  # Executes the conversion.
  #
  # Returns the number of lines written.
  def execute
    CALLS.sum do |call, cell|
      samples(cell).each do |row, copy|
        messages = NpcPrompt.public_send(call, row, Currency.pick(row, @currencies, copy))
        @io.puts JSON.generate({ 'messages' => messages })
      end.size
    end
  end

  private

  def samples(cell)
    return @rows.map { |row| [row, 0] } unless @split == 'train'

    Rebalancing.new(@rows, cell).execute
  end
end
