# frozen_string_literal: true

require 'spec_helper'
require 'json'
require_relative '../../support/rows'
require_relative '../../../lib/evaluation/evaluation'

RSpec.describe Evaluation do
  # Answers every request with a fixed reply and records the messages it got.
  let(:fake_client) do
    Class.new do
      attr_reader :requests

      def initialize(reply)
        @reply = reply
        @requests = []
      end

      def complete(messages)
        @requests << messages
        @reply
      end
    end
  end
  let(:extract_client) { fake_client.new('{"intent":"offer","attitude":"plain","offer":3619}') }
  let(:render_client) { fake_client.new(JSON.generate('message' => '4606星幣。')) }

  describe '#execute' do
    subject(:results) { described_class.new([VALID_ROW], extract_client, render_client).execute }

    it { expect(results.size).to eq(1) }
    it { expect(results.first['currency']).to be_in_test_currencies }

    it 'is expected to send each call its prompt without the reference reply' do
      results
      expect([extract_client.requests.first.map { |m| m['role'] }, render_client.requests.first.last['role']])
        .to eq([%w[system user], 'user'])
    end

    it { expect(results.first['extract']).to include('extract_match' => true) }
    it { expect(results.first).to include('extract_reply', 'render_reply', 'render', 'latency') }

    def be_in_test_currencies
      satisfy { |currency| Currency::TEST.include?(currency) }
    end
  end

  describe '.summary' do
    subject(:summary) { described_class.summary(described_class.new([VALID_ROW], extract_client, render_client).execute) }

    it { expect(summary.keys).to include('extract', 'render', 'latency_mean', 'latency_p95') }
  end
end
