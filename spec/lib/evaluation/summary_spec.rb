# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/evaluation/summary'

RSpec.describe Evaluation::Summary do
  describe '.call' do
    subject(:summary) { described_class.call(results) }

    let(:results) do
      [
        { 'extract' => { 'intent_match' => true }, 'render' => { 'price_said' => true }, 'latency' => 0.2 },
        { 'extract' => { 'intent_match' => false }, 'render' => { 'price_said' => nil }, 'latency' => 0.4 }
      ]
    end

    it { expect(summary['total']).to eq(2) }
    it { expect(summary['extract']['intent_match']).to include('rate' => 0.5, 'total' => 2) }

    it 'is expected to count a metric only on the rows it applies to' do
      expect(summary['render']['price_said']).to include('rate' => 1.0, 'total' => 1)
    end

    it { expect(summary['latency_mean']).to eq(0.3) }
    it { expect(summary['latency_p95']).to eq(0.4) }

    context 'when there are no results' do
      let(:results) { [] }

      it { is_expected.to include('total' => 0, 'latency_mean' => 0.0) }
    end
  end

  describe '.wilson_lower' do
    it { expect(described_class.wilson_lower(95, 100)).to eq(0.888) }
    it { expect(described_class.wilson_lower(10, 10)).to be < 1.0 }
    it { expect(described_class.wilson_lower(0, 0)).to eq(0.0) }
  end
end
