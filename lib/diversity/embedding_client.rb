# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

class Diversity
  ##
  # = Diversity::EmbeddingClient
  # Requests sentence-similarity embeddings from an OpenAI-compatible embeddings endpoint.
  #
  # == Reference
  # - {docs/tools/diversity.md}[docs/tools/diversity.md]
  ##
  class EmbeddingClient
    ##
    # Raised when the endpoint does not return embeddings.
    ##
    class Error < StandardError; end

    PREFIX = 'task: sentence similarity | query: '
    BATCH_SIZE = 64

    # Creates a new EmbeddingClient instance.
    #
    # endpoint - Base URL ending with the API version, e.g. http://127.0.0.1:1234/v1
    # model - Embedding model name sent with each request.
    def initialize(endpoint, model:)
      @uri = URI.join("#{endpoint.chomp('/')}/", 'embeddings')
      @model = model
    end

    # Returns one embedding (Array of Float) per text, in order.
    def embed(texts)
      texts.each_slice(BATCH_SIZE).flat_map { |batch| request(batch) }
    end

    private

    def request(batch)
      body = JSON.generate({ 'model' => @model, 'input' => batch.map { |text| PREFIX + text } })
      response = Net::HTTP.post(@uri, body, 'Content-Type' => 'application/json')
      raise Error, "HTTP #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body).fetch('data').sort_by { |item| item['index'].to_i }.map { |item| item['embedding'] }
    end
  end
end
