# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/bargaining_format'

RSpec.describe BargainingFormat do
  # An Epic sword at expected price 40 with a Neutral merchant: opening 60, floor 48.
  let(:row) do
    { 'item_name' => '長劍', 'item_rarity' => 'Epic', 'item_expected_price' => '40', 'relationship_status' => 'Neutral',
      'input' => '56金幣', 'output' => '{"action":"sell"}', 'round' => '3', 'patience' => '3', 'counter_price' => '58',
      'best_offer' => '50', 'last_offer' => '50', 'intent' => 'offer', 'rude' => 'false', 'player_offer' => '56' }
  end

  describe '.bargaining?' do
    it { expect(described_class.bargaining?(row)).to be true }
    it { expect(described_class.bargaining?(row.merge('round' => ''))).to be false }
  end

  describe '.last_exchange' do
    context 'when the player has offered before' do
      it { expect(described_class.last_exchange(row)).to eq('Player last offered 50. You countered at 58.') }
    end

    context 'when the player has not offered yet' do
      it { expect(described_class.last_exchange(row.merge('last_offer' => ''))).to eq('You quoted 58.') }
    end

    context 'when the player declined a deal at their offer' do
      it do
        expect(described_class.last_exchange(row.merge('best_offer' => '60', 'last_offer' => '60')))
          .to eq('You agreed to sell at 60; the player has not bought it yet.')
      end
    end

    context 'when the player declined a friend\'s deal at the counter' do
      it do
        expect(described_class.last_exchange(row.merge('relationship_status' => 'Friendly', 'best_offer' => '60',
                                                       'last_offer' => '60')))
          .to eq('You agreed to sell at 58; the player has not bought it yet.')
      end
    end
  end

  describe '.extraction_conversation' do
    subject(:messages) { described_class.extraction_conversation(row) }

    it 'is expected to show the counter before the turn' do
      expect(messages.first['content']).to include('- Counter Price: 58', '- Item: 長劍')
    end

    it { expect(messages.last['content']).to eq('{"intent":"offer","rude":false,"player_offer":56}') }
  end

  describe '.response_conversation' do
    subject(:messages) { described_class.response_conversation(row) }

    it 'is expected to show the state after the game step' do
      expect(messages.first['content']).to include('- Opening Price: 60', '- Player Offer: 56',
                                                   '- Counter Price: 55', '- Patience: 3', '- Round: 3')
    end

    it { expect(messages.last['content']).to eq('{"action":"sell"}') }
  end
end
