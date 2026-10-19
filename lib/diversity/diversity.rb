# frozen_string_literal: true

require 'json'
require 'numo/narray'
require_relative 'text'
require_relative 'tfidf'
require_relative 'probe'

##
# = Diversity
# Measures whether the wording of a dataset split varies enough for a model to learn rules instead of phrasings.
# Uses dependency injection to accept the dataset, an optional reference split, and an optional embedding client.
#
# == Reference
# - {docs/tools/diversity.md}[docs/tools/diversity.md]
##
class Diversity
  THRESHOLDS = {
    'redundant' => 0.02, 'near_duplicate' => 0.2, 'semantic_duplicate' => 0.2, 'against' => 0.05, 'offer_outcome' => 0.05
  }.freeze
  NEAR_SIMILARITY = 0.8
  SEMANTIC_SIMILARITY = 0.9
  FIELDS = %w[input message].freeze
  EXAMPLE_LIMIT = 5
  OPENING_LENGTH = 4

  # Creates a new Diversity instance.
  #
  # dataset - The Dataset (or Array of rows) to measure.
  # against - Optional reference Dataset that the measured rows must not repeat.
  # embedder - Optional object responding to embed(texts) with one vector per text.
  def initialize(dataset, against: nil, embedder: nil)
    @entries = dataset.map { |row| entry(row) }
    @references = against&.map { |row| entry(row) }
    @embedder = embedder
  end

  # Executes the measurement.
  #
  # Returns the report hash; its 'pass' is false when any check fails.
  def execute
    report = { 'rows' => @entries.size }
    FIELDS.each { |field| report[field] = measure_field(field) }
    report['offer_outcome'] = offer_outcome
    report['labels'] = labels
    report['pass'] = checks(report).all? { |check| check['pass'] }
    report
  end

  private

  def entry(row)
    output = JSON.parse(row['output'])
    {
      'input' => Text.normalize(row['input'], row['item_name']),
      'message' => Text.normalize(output['message'], row['item_name']),
      'relationship' => row['relationship_status'], 'action' => output['action'],
      'friendship_change' => output.dig('parameters', 'friendship_change').to_s,
      'bargaining' => !row['round'].to_s.empty?, 'intent' => row['intent'], 'rude' => row['rude']
    }
  end

  def checks(report)
    FIELDS.flat_map { |field| report[field]['checks'].values } << report['offer_outcome']
  end

  def measure_field(field)
    texts = @entries.map { |entry| entry[field] }
    distinct = texts.uniq
    {
      'distinct' => distinct.size,
      'openings' => texts.map { |text| text[0, OPENING_LENGTH] }.tally.max_by(EXAMPLE_LIMIT) { |_, count| count },
      'checks' => {
        'redundant' => redundant(field),
        'near_duplicate' => near_duplicate(distinct),
        'semantic_duplicate' => semantic_duplicate(distinct),
        'against' => against(field, distinct)
      }
    }
  end

  def redundant(field)
    keys = @entries.map { |entry| [entry[field], entry['relationship'], entry['action']] }
    rate_check('redundant', keys.empty? ? 0.0 : 1 - keys.uniq.size.fdiv(keys.size))
  end

  def near_duplicate(distinct)
    return skipped if distinct.size < 2

    all = distinct.each_index.to_a
    neighbours = Tfidf.new(distinct).nearest(all, all)
    similar_check('near_duplicate', distinct, distinct, neighbours, NEAR_SIMILARITY)
  end

  def semantic_duplicate(distinct)
    return skipped if @embedder.nil? || distinct.size < 2

    neighbours = nearest_embeddings(@embedder.embed(distinct))
    similar_check('semantic_duplicate', distinct, distinct, neighbours, SEMANTIC_SIMILARITY)
  end

  def against(field, distinct)
    return skipped if @references.nil? || distinct.empty?

    references = @references.map { |entry| entry[field] }.uniq
    combined = distinct + references
    candidates = (distinct.size...combined.size).to_a
    neighbours = Tfidf.new(combined).nearest(distinct.each_index.to_a, candidates)
                      .map { |score, index| [score, index && (index - distinct.size)] }
    similar_check('against', distinct, references, neighbours, NEAR_SIMILARITY)
  end

  # Centres the embeddings on their mean so short lines stop sharing one dominant direction.
  def nearest_embeddings(vectors)
    matrix = Numo::DFloat.cast(vectors)
    matrix -= matrix.mean(axis: 0)
    matrix /= Numo::NMath.sqrt((matrix**2).sum(axis: 1)).expand_dims(1)
    similarity = matrix.dot(matrix.transpose)
    similarity.shape[0].times.map do |index|
      similarity[index, index] = -Float::INFINITY
      best = similarity[index, true].max_index
      [similarity[index, best], best]
    end
  end

  def similar_check(name, texts, others, neighbours, minimum)
    hits = neighbours.each_with_index.select { |(score, _), _| score >= minimum }
    examples = neighbours.each_with_index.reject { |(_, other), _| other.nil? }
                         .map { |(score, other), index| [texts[index], others[other], score.round(3)] }
                         .uniq { |text, other, _| [text, other].sort }
                         .max_by(EXAMPLE_LIMIT) { |_, _, score| score }
    rate_check(name, hits.size.fdiv(texts.size)).merge('examples' => examples)
  end

  def offer_outcome
    offers = @entries.select { |entry| entry['bargaining'] && entry['intent'] == 'offer' && entry['rude'] != 'true' }
    probe = Probe.new(offers.map { |entry| entry['input'] }, offers.map { |entry| entry['action'] })
    return skipped unless probe.measurable?

    accuracy = probe.accuracy
    margin = accuracy - probe.majority
    { 'total' => offers.size, 'accuracy' => accuracy.round(3), 'majority' => probe.majority.round(3),
      'margin' => margin.round(3), 'threshold' => THRESHOLDS['offer_outcome'],
      'pass' => margin <= THRESHOLDS['offer_outcome'] }
  end

  def labels
    bargaining = @entries.select { |entry| entry['bargaining'] }
    { 'action' => @entries, 'friendship_change' => @entries, 'intent' => bargaining, 'rude' => bargaining }
      .to_h { |label, entries| [label, label_report(entries, label)] }
  end

  def label_report(entries, label)
    probe = Probe.new(entries.map { |entry| entry['input'] }, entries.map { |entry| entry[label] })
    return { 'skipped' => true } unless probe.measurable?

    { 'total' => entries.size, 'accuracy' => probe.accuracy.round(3), 'majority' => probe.majority.round(3),
      'indicative' => probe.indicative }
  end

  def rate_check(name, rate)
    { 'rate' => rate.round(3), 'threshold' => THRESHOLDS[name], 'pass' => rate <= THRESHOLDS[name] }
  end

  def skipped
    { 'skipped' => true, 'pass' => true }
  end
end
