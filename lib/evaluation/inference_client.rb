# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

class Evaluation
  ##
  # = Evaluation::InferenceClient
  # Requests replies from an OpenAI-compatible chat completions endpoint.
  # Uses greedy decoding so an evaluation run is reproducible.
  #
  # == Reference
  # - {docs/tools/evaluation.md}[docs/tools/evaluation.md]
  ##
  class InferenceClient
    ##
    # Raised when the endpoint does not return a completion.
    ##
    class Error < StandardError; end

    # Creates a new InferenceClient instance.
    #
    # endpoint - Base URL ending with the API version, e.g. http://127.0.0.1:8080/v1
    # response_format - Optional guided decoding contract sent as-is.
    # cache_prompt - false asks llama-server not to reuse the previous request's cache.
    # max_tokens - Upper bound on generated tokens.
    def initialize(endpoint, response_format: nil, cache_prompt: true, max_tokens: 256)
      @uri = URI.join("#{endpoint.chomp('/')}/", 'chat/completions')
      @response_format = response_format
      @cache_prompt = cache_prompt
      @max_tokens = max_tokens
    end

    # Returns the assistant reply content for the messages.
    def complete(messages)
      response = Net::HTTP.post(@uri, JSON.generate(body(messages)), 'Content-Type' => 'application/json')
      raise Error, "HTTP #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body).dig('choices', 0, 'message', 'content').to_s
    end

    private

    def body(messages)
      request = { 'messages' => messages, 'temperature' => 0, 'max_tokens' => @max_tokens }
      request['response_format'] = @response_format if @response_format
      request['cache_prompt'] = false unless @cache_prompt
      request
    end
  end
end
