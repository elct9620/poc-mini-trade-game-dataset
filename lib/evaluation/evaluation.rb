# frozen_string_literal: true

require_relative '../currency'
require_relative '../npc_prompt'
require_relative 'judge'
require_relative 'summary'

##
# = Evaluation
# Makes both NPC calls for every row of a split and checks each reply against the row.
# Prompts use the test currencies, as a test conversion does. Uses dependency injection to accept
# the dataset and one inference client per call, since each call sends its own reply schema.
#
# == Reference
# - {docs/tools/evaluation.md}[docs/tools/evaluation.md]
##
class Evaluation
  # Creates a new Evaluation instance.
  #
  # dataset - The rows to evaluate.
  # extract_client - An object that responds to complete(messages) for the extract call.
  # render_client - The same for the render call.
  # collision - true scores only rows whose line names the item, with the item's word as the currency.
  def initialize(dataset, extract_client, render_client, collision: false)
    @dataset = dataset
    @extract_client = extract_client
    @render_client = render_client
    @collision = collision
  end

  # Executes the evaluation.
  #
  # Returns one hash per row with both replies, their checks, and the turn's latency in seconds.
  def execute
    rows.map do |row|
      currency = @collision ? Currency.collision(row) : Currency.pick(row, Currency::TEST)
      (extract, render), latency = timed do
        [@extract_client.complete(NpcPrompt.extract(row, currency)[0..-2]),
         @render_client.complete(NpcPrompt.render(row, currency)[0..-2])]
      end
      { 'id' => row['id'], 'currency' => currency, 'extract_reply' => extract, 'render_reply' => render,
        'extract' => Judge.extract(row, extract), 'render' => Judge.render(row, render, currency), 'latency' => latency }
    end
  end

  # Returns the summary of results; see Evaluation::Summary.
  def self.summary(results)
    Summary.call(results)
  end

  private

  def rows
    all = @dataset.map(&:to_h)
    @collision ? all.select { |row| Currency.collides?(row) } : all
  end

  def timed
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    value = yield
    [value, Process.clock_gettime(Process::CLOCK_MONOTONIC) - started]
  end
end
