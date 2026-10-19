# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'socket'
require_relative '../../../lib/diversity/embedding_client'

RSpec.describe Diversity::EmbeddingClient do
  # Serves one HTTP response and records the request body, standing in for the embedding server.
  let(:server) { TCPServer.new('127.0.0.1', 0) }
  let(:endpoint) { "http://127.0.0.1:#{server.addr[1]}/v1" }
  let(:requests) { [] }
  let!(:thread) do
    # Resolve lets before the thread starts; RSpec memoization locks across threads.
    status = self.status
    body = self.body
    requests = self.requests
    Thread.new do
      socket = server.accept
      length = 0
      while (line = socket.gets) != "\r\n"
        length = line.split(':').last.to_i if line.downcase.start_with?('content-length')
      end
      requests << JSON.parse(socket.read(length))
      socket.write("HTTP/1.1 #{status}\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\n" \
                   "Connection: close\r\n\r\n#{body}")
      socket.close
    end
  end
  let(:status) { '200 OK' }
  let(:body) do
    JSON.generate({ 'data' => [{ 'index' => 1, 'embedding' => [0.0, 1.0] }, { 'index' => 0, 'embedding' => [1.0, 0.0] }] })
  end
  let(:client) { described_class.new(endpoint, model: 'embedding-gemma') }

  after do
    thread.join(1)
    server.close
  end

  describe '#embed' do
    context 'when the server returns embeddings out of order' do
      subject { client.embed(%w[不夠 成交]) }

      it { is_expected.to eq([[1.0, 0.0], [0.0, 1.0]]) }
    end

    context 'when texts are sent' do
      it 'is expected to prefix them with the sentence similarity task' do
        client.embed(%w[不夠 成交])
        thread.join(1)
        expect(requests.first['input']).to eq(['task: sentence similarity | query: 不夠',
                                               'task: sentence similarity | query: 成交'])
      end
    end

    context 'when the server returns an error' do
      subject(:embed) { client.embed(['不夠']) }

      let(:status) { '500 Internal Server Error' }
      let(:body) { '{"error":"boom"}' }

      it { expect { embed }.to raise_error(Diversity::EmbeddingClient::Error, /HTTP 500/) }
    end
  end
end
