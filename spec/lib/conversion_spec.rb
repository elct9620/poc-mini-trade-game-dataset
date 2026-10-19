# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'stringio'
require_relative '../../lib/conversion'

RSpec.describe Conversion do
  describe '#execute' do
    subject(:execute) { described_class.new(dataset, io).execute }

    let(:io) { StringIO.new }
    let(:lines) { io.string.lines.map { |line| JSON.parse(line) } }

    context 'when dataset has rows' do
      let(:dataset) do
        [
          { 'item_name' => '鐵劍', 'item_rarity' => 'Common', 'item_expected_price' => '100',
            'relationship_status' => 'Friendly', 'input' => '我要買劍', 'output' => '{"action":"sell"}' },
          { 'item_name' => '精靈弓', 'item_rarity' => 'Rare', 'item_expected_price' => '500',
            'relationship_status' => 'Hostile', 'input' => '給我弓', 'output' => '{"action":"refuse"}' }
        ]
      end

      it { is_expected.to eq(2) }

      it 'is expected to write one line per row' do
        execute
        expect(lines.size).to eq(2)
      end

      it 'is expected to end each line with the row output as assistant reply' do
        execute
        expect(lines.map { |line| line['messages'].last['content'] }).to eq(['{"action":"sell"}', '{"action":"refuse"}'])
      end
    end

    context 'when dataset has a bargaining row' do
      let(:dataset) do
        [{ 'item_name' => '長劍', 'item_rarity' => 'Epic', 'item_expected_price' => '40', 'relationship_status' => 'Neutral',
           'input' => '50金幣如何？', 'output' => '{"action":"negotiate"}', 'round' => '2', 'patience' => '3',
           'counter_price' => '60', 'best_offer' => '', 'last_offer' => '', 'intent' => 'offer', 'rude' => 'none',
           'player_offer' => '50' }]
      end

      it { is_expected.to eq(2) }

      it 'is expected to write the extraction reply then the response reply' do
        execute
        expect(lines.map { |line| line['messages'].last['content'] })
          .to eq(['{"intent":"offer","rude":"none","player_offer":50}', '{"action":"negotiate"}'])
      end
    end

    context 'when dataset is empty' do
      let(:dataset) { [] }

      it { is_expected.to eq(0) }
    end
  end
end
