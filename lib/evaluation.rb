# frozen_string_literal: true

require 'json'
require_relative 'chat_format'
require_relative 'validation_error'

##
# = Evaluation
# Asks a model to answer each dataset row and judges the reply with the dataset rules.
# Uses dependency injection to accept dataset, inference client, and validators.
#
# == Reference
# - {docs/features/evaluation.md}[docs/features/evaluation.md]
##
class Evaluation
  # Creates a new Evaluation instance.
  #
  # dataset - The Dataset object holding prompts and reference outputs.
  # client - An object that responds to complete(messages) and returns the reply text.
  # validators - Array of validator objects that respond to validate(row).
  def initialize(dataset, client, validators)
    @dataset = dataset
    @client = client
    @validators = validators
  end

  # Executes the evaluation.
  #
  # Returns an array of hashes with the reply, rule errors, and actions of each row.
  def execute
    @dataset.map { |row| evaluate(row) }
  end

  # Summarizes results into rates between 0 and 1.
  #
  # Returns a hash with total, json_valid, rule_pass, action_match, and reply latency in seconds.
  def self.summary(results)
    total = results.size
    rate = ->(key) { total.zero? ? 0.0 : results.count { |result| result[key] }.fdiv(total) }
    latencies = results.map { |result| result['latency'] }.sort

    { 'total' => total, 'json_valid' => rate['json_valid'], 'rule_pass' => rate['rule_pass'],
      'action_match' => rate['action_match'],
      'latency_mean' => total.zero? ? 0.0 : (latencies.sum / total).round(3),
      'latency_p95' => total.zero? ? 0.0 : latencies[(0.95 * (total - 1)).ceil].round(3) }
  end

  private

  def evaluate(row)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    reply = @client.complete(ChatFormat.prompt(row))
    latency = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    actual = parse_object(reply)
    errors = actual ? rule_errors(row.to_h.merge('output' => reply)) : ['Output is not a JSON object']
    expected_action = JSON.parse(row['output'])['action']
    actual_action = actual&.dig('action')

    {
      'id' => row['id'], 'output' => reply, 'errors' => errors,
      'json_valid' => !actual.nil?, 'rule_pass' => errors.empty?,
      'expected_action' => expected_action, 'actual_action' => actual_action,
      'action_match' => actual_action == expected_action, 'latency' => latency
    }
  end

  def parse_object(reply)
    data = JSON.parse(reply)
    data.is_a?(Hash) ? data : nil
  rescue JSON::ParserError
    nil
  end

  def rule_errors(candidate)
    @validators.filter_map do |validator|
      validator.validate(candidate)
      nil
    rescue ValidationError => e
      e.message
    end
  end
end
