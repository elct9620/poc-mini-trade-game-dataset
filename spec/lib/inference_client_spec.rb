# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'socket'
require_relative '../../lib/inference_client'

RSpec.describe InferenceClient do
  # Serves one HTTP response and records the request body, standing in for the model server.
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
  let(:body) { JSON.generate({ 'choices' => [{ 'message' => { 'content' => '{"action":"talk"}' } }] }) }
  let(:messages) { [{ 'role' => 'user', 'content' => '你好' }] }

  after do
    thread.join(1)
    server.close
  end

  describe '#complete' do
    context 'when the server returns a completion' do
      subject { described_class.new(endpoint).complete(messages) }

      it { is_expected.to eq('{"action":"talk"}') }
    end

    context 'when a response format is given' do
      subject(:client) { described_class.new(endpoint, response_format: { 'type' => 'json_object' }) }

      it 'is expected to send it with greedy decoding' do
        client.complete(messages)
        thread.join(1)
        expect(requests.first).to include('response_format' => { 'type' => 'json_object' }, 'temperature' => 0)
      end
    end

    context 'when the server returns an error' do
      subject(:complete) { described_class.new(endpoint).complete(messages) }

      let(:status) { '500 Internal Server Error' }
      let(:body) { '{"error":"boom"}' }

      it { expect { complete }.to raise_error(InferenceClient::Error, /HTTP 500/) }
    end
  end
end
