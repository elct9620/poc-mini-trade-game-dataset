# frozen_string_literal: true

require_relative 'text'

class Diversity
  ##
  # = Diversity::Tfidf
  # Lexical similarity between texts as the cosine of character 2–3 gram TF-IDF vectors.
  # Nearest neighbours are found through an inverted index, so only texts sharing a gram are compared.
  #
  # == Reference
  # - {docs/tools/diversity.md}[docs/tools/diversity.md]
  ##
  class Tfidf
    SIZES = (2..3)

    # Creates a new Tfidf instance whose IDF is fitted on all texts.
    #
    # texts - Array of normalised texts.
    def initialize(texts)
      grams = texts.map { |text| Text.ngrams(text, SIZES).tally }
      document_frequency = Hash.new(0)
      grams.each { |counts| counts.each_key { |gram| document_frequency[gram] += 1 } }
      idf = document_frequency.transform_values { |count| Math.log((1.0 + texts.size) / (1 + count)) + 1 }
      @vectors = grams.map { |counts| unit(counts.to_h { |gram, count| [gram, count * idf[gram]] }) }
    end

    # Returns, for each text index in queries, [similarity, index] of its most similar text in candidates.
    # A text is never its own neighbour; a text sharing no gram gets [0.0, nil].
    def nearest(queries, candidates)
      index = Hash.new { |hash, gram| hash[gram] = [] }
      candidates.each { |candidate| @vectors[candidate].each { |gram, weight| index[gram] << [candidate, weight] } }
      queries.map { |query| best(query, index) }
    end

    private

    def best(query, index)
      scores = Hash.new(0.0)
      @vectors[query].each do |gram, weight|
        index.fetch(gram, []).each { |candidate, other| scores[candidate] += weight * other }
      end
      scores.delete(query)
      candidate, score = scores.max_by { |_, value| value }
      [score || 0.0, candidate]
    end

    def unit(vector)
      norm = Math.sqrt(vector.values.sum { |value| value * value })
      norm.zero? ? vector : vector.transform_values { |value| value / norm }
    end
  end
end
