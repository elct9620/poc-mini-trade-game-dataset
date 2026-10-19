# frozen_string_literal: true

require 'spec_helper'
require 'json'
require_relative '../../../lib/diversity/diversity'

RSpec.describe Diversity do
  def row(input, relationship: 'Neutral', action: 'talk', message: '歡迎光臨。', item: '鐵劍', bargaining: {})
    output = JSON.generate({ 'action' => action, 'message' => message, 'parameters' => { 'friendship_change' => 0 } })
    { 'item_name' => item, 'relationship_status' => relationship, 'input' => input, 'output' => output }
      .merge(bargaining)
  end

  # Returns one fixed vector per text, standing in for an embedding model; other texts get unrelated one-hot vectors.
  let(:embedder_class) do
    Struct.new(:vectors) do
      def embed(texts)
        texts.each_with_index.map do |text, index|
          vectors.fetch(text) { Array.new(texts.size) { |position| position == index ? 1.0 : 0.0 } }
        end
      end
    end
  end

  let(:varied) do
    [row('鐵劍怎麼賣？', message: '一百金幣。'), row('這東西耐用嗎？', message: '很耐用。'),
     row('你這騙子，滾。', message: '請你離開。'), row('今天天氣真好。', message: '是啊。')]
  end

  describe '#execute' do
    subject(:report) { described_class.new(rows, against: against, embedder: embedder).execute }

    let(:rows) { varied }
    let(:against) { nil }
    let(:embedder) { nil }

    context 'when the wording varies' do
      it { expect(report['pass']).to be(true) }
    end

    context 'when a line repeats with the same relationship and action' do
      let(:rows) { varied + [row('銅劍怎麼賣？', item: '銅劍', message: '一百金幣。')] }

      it { expect(report.dig('input', 'checks', 'redundant', 'pass')).to be(false) }
    end

    context 'when a line repeats with a different relationship' do
      let(:rows) { varied + [row('鐵劍怎麼賣？', relationship: 'Allied', message: '送你也行。')] }

      it { expect(report.dig('input', 'checks', 'redundant', 'rate')).to eq(0.0) }
    end

    context 'when no embedding client is given' do
      it { expect(report.dig('input', 'checks', 'semantic_duplicate')).to eq({ 'skipped' => true, 'pass' => true }) }
    end

    context 'when two lines mean the same' do
      let(:embedder) do
        embedder_class.new({ '@怎麼賣？' => [1.0, 0.0, 0.1], '這東西耐用嗎？' => [0.0, 1.0, 0.0],
                             '你這騙子，滾。' => [1.0, 0.0, 0.0], '今天天氣真好。' => [-1.0, -1.0, 0.0] })
      end

      it { expect(report.dig('input', 'checks', 'semantic_duplicate', 'pass')).to be(false) }
    end

    context 'when a line repeats the reference split' do
      let(:against) { [row('鐵劍怎麼賣？', relationship: 'Hostile', action: 'negotiate')] }

      it { expect(report.dig('input', 'checks', 'against', 'rate')).to eq(0.25) }
    end

    context 'when the wording of bargaining offers gives the outcome away' do
      let(:rows) do
        offer = { 'round' => '2', 'intent' => 'offer', 'rude' => 'false', 'counter_price' => '95' }
        deals = Array.new(10) do |index|
          row("行，就#{100 + index}金幣。", action: 'sell', bargaining: offer.merge('player_offer' => (100 + index).to_s))
        end
        counters = Array.new(10) do |index|
          row("#{50 + index}金幣可以嗎？", action: 'negotiate', bargaining: offer.merge('player_offer' => (50 + index).to_s))
        end
        deals.zip(counters).flatten
      end

      it { expect(report.dig('offer_outcome', 'pass')).to be(false) }
    end

    context 'when only offers that accept the counter use accepting words' do
      let(:rows) do
        offer = { 'round' => '2', 'intent' => 'offer', 'rude' => 'false', 'counter_price' => '100' }
        accepts = Array.new(10) { row('好，就照你說的。', action: 'sell', bargaining: offer.merge('player_offer' => '100')) }
        counters = Array.new(10) do |index|
          row("#{50 + index}金幣可以嗎？", action: index.even? ? 'sell' : 'negotiate', bargaining: offer.merge('player_offer' => '90'))
        end
        accepts.zip(counters).flatten
      end

      it { expect(report.dig('offer_outcome', 'total')).to eq(10) }
    end
  end
end
