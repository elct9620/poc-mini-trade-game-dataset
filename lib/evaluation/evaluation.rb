# frozen_string_literal: true

require 'json'
require_relative '../bargaining_format'
require_relative '../chat_format'
require_relative '../validation_error'
require_relative 'response_schema'
require_relative 'simplified_characters'

##
# = Evaluation
# Asks a model to answer each dataset row and judges the reply with the dataset rules.
# A bargaining row takes two calls: the extraction call, then the response call built from the reference labels.
# Uses dependency injection to accept dataset, inference clients, and validators.
#
# == Reference
# - {docs/tools/evaluation.md}[docs/tools/evaluation.md]
##
class Evaluation
  # Creates a new Evaluation instance.
  #
  # dataset - The Dataset object holding prompts and reference outputs.
  # client - An object that responds to complete(messages) and returns the reply text.
  # validators - Array of validator objects that respond to validate(row).
  # extraction_client - The client for bargaining extraction calls, which may use its own reply schema.
  def initialize(dataset, client, validators, extraction_client: client)
    @dataset = dataset
    @client = client
    @validators = validators
    @extraction_client = extraction_client
  end

  # Executes the evaluation.
  #
  # Returns an array of hashes with the reply, rule errors, and actions of each row.
  def execute
    @dataset.map { |row| BargainingFormat.bargaining?(row) ? evaluate_bargaining(row) : evaluate_single(row) }
  end

  RESPONSE_METRICS = %w[json_valid rule_pass action_match friendship_match message_clean message_traditional].freeze
  MESSAGE_PATTERN = /\A[#{MESSAGE_CHARACTERS}]+\z/
  EXTRACTION_METRICS = %w[intent_match rude_match offer_match].freeze

  # Summarizes results into rates between 0 and 1, overall and per row type.
  #
  # Returns a hash with total, the response metrics, the extraction metrics and deal_match of bargaining rows,
  # latency in seconds, and the response metrics again under 'single' and 'bargaining'.
  def self.summary(results)
    bargaining, single = results.partition { |result| result['bargaining'] }
    latencies = results.map { |result| result['latency'] }.sort
    total = results.size

    rates(results, RESPONSE_METRICS)
      .merge(rates(bargaining, EXTRACTION_METRICS).except('total'))
      .merge('deal_match' => rate(bargaining.select { |result| result['deal'] }, 'deal_match'),
             'latency_mean' => total.zero? ? 0.0 : (latencies.sum / total).round(3),
             'latency_p95' => total.zero? ? 0.0 : latencies[(0.95 * (total - 1)).ceil].round(3),
             'single' => rates(single, RESPONSE_METRICS), 'bargaining' => rates(bargaining, RESPONSE_METRICS))
  end

  def self.rates(results, metrics)
    { 'total' => results.size }.merge(metrics.to_h { |metric| [metric, rate(results, metric)] })
  end

  def self.rate(results, metric)
    results.empty? ? 0.0 : results.count { |result| result[metric] }.fdiv(results.size)
  end

  private_class_method :rates, :rate

  private

  def evaluate_single(row)
    reply, latency = timed { @client.complete(ChatFormat.prompt(row)) }
    judge(row, reply).merge('bargaining' => false, 'latency' => latency)
  end

  # Times the whole turn, so latency covers both calls the game makes.
  def evaluate_bargaining(row)
    (extraction_reply, reply), latency = timed do
      [@extraction_client.complete(BargainingFormat.extraction_conversation(row)[0..-2]),
       @client.complete(BargainingFormat.response_conversation(row)[0..-2])]
    end
    judge(row, reply).then do |result|
      result.merge('bargaining' => true, 'extraction' => extraction_reply, 'latency' => latency)
            .merge(judge_extraction(row, parse_object(extraction_reply)))
            .merge(judge_deal(row, result))
    end
  end

  def timed
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    value = yield
    [value, Process.clock_gettime(Process::CLOCK_MONOTONIC) - started]
  end

  def judge(row, reply)
    actual = parse_object(reply)
    errors = actual ? rule_errors(row.to_h.merge('output' => reply)) : ['Output is not a JSON object']
    expected = JSON.parse(row['output'])
    expected_action = expected['action']
    actual_action = actual&.dig('action')

    {
      'id' => row['id'], 'output' => reply, 'errors' => errors,
      'json_valid' => !actual.nil?, 'rule_pass' => errors.empty?,
      'expected_action' => expected_action, 'actual_action' => actual_action,
      'action_match' => actual_action == expected_action,
      'friendship_match' => !actual.nil? && actual.dig('parameters', 'friendship_change') == expected.dig('parameters', 'friendship_change'),
      'message_clean' => actual&.dig('message').is_a?(String) && MESSAGE_PATTERN.match?(actual['message']),
      'message_traditional' => actual&.dig('message').is_a?(String) && actual['message'].each_char.none? { |char| SIMPLIFIED_CHARACTERS.key?(char) }
    }
  end

  def judge_extraction(row, extraction)
    offer = row['player_offer'].to_s.strip
    {
      'intent_match' => !extraction.nil? && extraction['intent'] == row['intent'],
      'rude_match' => !extraction.nil? && extraction['rude'] == row['rude'],
      'offer_match' => !extraction.nil? && extraction['player_offer'] == (offer.empty? ? nil : offer.to_i)
    }
  end

  # A deal row should sell; it matches only when the reply sells at the reference price.
  def judge_deal(row, result)
    deal = result['expected_action'] == 'sell'
    price = ->(reply) { parse_object(reply)&.dig('parameters', 'price') }
    { 'deal' => deal, 'deal_match' => deal && result['action_match'] && price[result['output']] == price[row['output']] }
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
