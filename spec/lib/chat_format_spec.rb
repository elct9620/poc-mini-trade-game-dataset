# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/chat_format'

RSpec.describe ChatFormat do
  let(:row) do
    {
      'item_name' => '生命藥水',
      'item_rarity' => 'Common',
      'item_expected_price' => '50',
      'relationship_status' => 'Neutral',
      'input' => '我想買這個生命藥水',
      'output' => '{"action":"sell"}'
    }
  end

  describe '.prompt' do
    subject(:messages) { described_class.prompt(row) }

    it { expect(messages.map { |message| message['role'] }).to eq(%w[system user]) }
    it { expect(messages[0]['content']).to include('- Name: 生命藥水') }
    it { expect(messages[0]['content']).to include('- Rarity: Common') }
    it { expect(messages[0]['content']).to include('- Expected Price: 50') }
    it { expect(messages[0]['content']).to include('- Asking Price: 50') }
    it { expect(messages[0]['content']).to include('Relatioship: Neutral') }
    it { expect(messages[1]['content']).to eq('我想買這個生命藥水') }
  end

  describe '.asking_price' do
    subject { described_class.asking_price(row.merge(overrides)) }

    context 'when a Hostile player buys a Common item' do
      let(:overrides) { { 'item_expected_price' => '15', 'relationship_status' => 'Hostile' } }

      it { is_expected.to eq(20) }
    end

    context 'when a Neutral player buys an Epic item' do
      let(:overrides) { { 'item_rarity' => 'Epic', 'item_expected_price' => '6500' } }

      it { is_expected.to eq(7800) }
    end

    context 'when an Allied player buys a Rare item' do
      let(:overrides) { { 'item_rarity' => 'Rare', 'item_expected_price' => '850', 'relationship_status' => 'Allied' } }

      it { is_expected.to eq(723) }
    end
  end

  describe '.conversation' do
    subject(:messages) { described_class.conversation(row) }

    it { expect(messages.last).to eq({ 'role' => 'assistant', 'content' => '{"action":"sell"}' }) }
  end
end
