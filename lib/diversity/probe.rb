# frozen_string_literal: true

require_relative 'text'

class Diversity
  ##
  # = Diversity::Probe
  # Measures how far a label can be predicted from wording alone, with a multinomial logistic regression
  # over binary character 1–3 grams, trained by SGD and scored by 5-fold cross-validation (fold = position modulo 5).
  #
  # == Reference
  # - {docs/tools/diversity.md}[docs/tools/diversity.md]
  ##
  class Probe
    SIZES = (1..3)
    FOLDS = 5
    MIN_ROWS = 10
    EPOCHS = 30
    LEARNING_RATE = 0.1
    SEED = 0
    INDICATIVE_MIN_COUNT = 5
    INDICATIVE_LIMIT = 5

    # Creates a new Probe instance.
    #
    # texts - Array of normalised texts.
    # labels - Array of labels, one per text.
    def initialize(texts, labels)
      grams = texts.map { |text| Text.ngrams(text, SIZES).uniq }
      @vocabulary = grams.flatten.tally
      index = @vocabulary.keys.each_with_index.to_h
      @features = grams.map { |row| row.map { |gram| index[gram] } }
      @labels = labels
      @classes = labels.uniq
    end

    # Returns whether there is enough to measure: at least MIN_ROWS rows and two labels.
    def measurable?
      @labels.size >= MIN_ROWS && @classes.size > 1
    end

    # Returns the cross-validated accuracy between 0 and 1.
    def accuracy
      correct = FOLDS.times.sum do |fold|
        held_out, training = @labels.each_index.partition { |index| (index % FOLDS) == fold }
        model = train(training)
        held_out.count { |index| predict(model, @features[index]) == @labels[index] }
      end
      correct.fdiv(@labels.size)
    end

    # Returns the share of the most frequent label.
    def majority
      @labels.tally.values.max.fdiv(@labels.size)
    end

    # Returns each label's n-grams (two characters or more, seen in INDICATIVE_MIN_COUNT rows) with the largest weights.
    def indicative
      model = train(@labels.each_index.to_a)
      common = @vocabulary.each_with_index.filter_map do |(gram, count), index|
        index if gram.length > 1 && count >= INDICATIVE_MIN_COUNT
      end
      grams = @vocabulary.keys
      @classes.each_with_index.to_h do |label, klass|
        [label, common.max_by(INDICATIVE_LIMIT) { |index| model[:weights][klass][index] }.map { |index| grams[index] }]
      end
    end

    private

    # Shuffles with a fixed seed and averages the weights over epochs, so identical lines with different
    # labels settle on their majority label instead of the last one seen, and a run is reproducible.
    def train(indices)
      weights = Array.new(@classes.size) { Array.new(@vocabulary.size, 0.0) }
      bias = Array.new(@classes.size, 0.0)
      average = { weights: Array.new(@classes.size) { Array.new(@vocabulary.size, 0.0) }, bias: Array.new(@classes.size, 0.0) }
      targets = @labels.map { |label| @classes.index(label) }
      random = Random.new(SEED)
      EPOCHS.times do |epoch|
        indices.shuffle(random: random).each { |index| step(weights, bias, @features[index], targets[index]) }
        accumulate(average, weights, bias, epoch + 1)
      end
      average
    end

    def accumulate(average, weights, bias, count)
      average[:weights].each_with_index do |row, klass|
        current = weights[klass]
        row.each_index { |feature| row[feature] += (current[feature] - row[feature]) / count }
      end
      average[:bias].each_index { |klass| average[:bias][klass] += (bias[klass] - average[:bias][klass]) / count }
    end

    def step(weights, bias, features, target)
      probabilities(weights, bias, features).each_with_index do |probability, klass|
        gradient = LEARNING_RATE * (probability - (klass == target ? 1.0 : 0.0))
        bias[klass] -= gradient
        row = weights[klass]
        features.each { |feature| row[feature] -= gradient }
      end
    end

    def probabilities(weights, bias, features)
      scores = weights.each_with_index.map { |row, klass| bias[klass] + features.sum { |feature| row[feature] } }
      top = scores.max
      exponents = scores.map { |score| Math.exp(score - top) }
      total = exponents.sum
      exponents.map { |value| value / total }
    end

    def predict(model, features)
      scores = probabilities(model[:weights], model[:bias], features)
      @classes[scores.each_with_index.max_by(&:first).last]
    end
  end
end
