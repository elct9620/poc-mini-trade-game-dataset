# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/negotiation'

RSpec.describe Negotiation do
  # An Epic item at expected price 40 with a Neutral merchant: floor 48, opening 60,
  # steps between 2 and 3 coins, and progress needs a raise of 3.
  let(:epic_neutral) do
    { 'item_rarity' => 'Epic', 'item_expected_price' => '40', 'relationship_status' => 'Neutral' }
  end

  def turn_row(base, state)
    base.merge({ 'round' => '2', 'patience' => '3', 'counter_price' => '60', 'best_offer' => '50',
                 'last_offer' => '50', 'intent' => 'offer', 'rude' => 'none', 'player_offer' => '' }.merge(state))
  end

  describe '.prices' do
    subject { described_class.prices(row) }

    context 'when a Neutral merchant sells a Common item' do
      let(:row) { { 'item_rarity' => 'Common', 'item_expected_price' => '10', 'relationship_status' => 'Neutral' } }

      it { is_expected.to eq(floor: 10, opening: 13) }
    end

    context 'when a Hostile merchant sells a Common item' do
      let(:row) { { 'item_rarity' => 'Common', 'item_expected_price' => '10', 'relationship_status' => 'Hostile' } }

      it { is_expected.to eq(floor: 13, opening: 17) }
    end

    context 'when an Allied merchant sells a Common item' do
      let(:row) { { 'item_rarity' => 'Common', 'item_expected_price' => '14', 'relationship_status' => 'Allied' } }

      it { is_expected.to eq(floor: 7, opening: 11) }
    end

    context 'when a Neutral merchant sells an Epic item' do
      let(:row) { epic_neutral }

      it { is_expected.to eq(floor: 48, opening: 60) }
    end
  end

  describe '.stated_numbers' do
    subject { described_class.stated_numbers(text) }

    context 'when the message mixes full-width digits and Chinese numerals' do
      let(:text) { '１８不行的話，二十金幣' }

      it { is_expected.to contain_exactly(18, 20) }
    end

    context 'when the message writes hundreds and ten thousands in Chinese' do
      let(:text) { '一萬兩千零五或三百' }

      it { is_expected.to contain_exactly(12_005, 300) }
    end

    context 'when the message has no number' do
      let(:text) { '好吧' }

      it { is_expected.to be_empty }
    end

    context 'when a numeral only forms a word' do
      let(:text) { '你是一個爛人，便宜一點，萬一呢' }

      it { is_expected.to be_empty }
    end

    context 'when a lone numeral comes before a coin unit or ends the clause' do
      let(:text) { '一塊錢賣我，或者五？' }

      it { is_expected.to contain_exactly(1, 5) }
    end
  end

  describe '.offer_stated?' do
    subject { described_class.offer_stated?(text, 14) }

    context 'when the player writes the offer' do
      let(:text) { '十四金幣' }

      it { is_expected.to be true }
    end

    context 'when the player names a different number' do
      let(:text) { '0 金幣' }

      it { is_expected.to be false }
    end

    context 'when the player writes no number' do
      let(:text) { '免費給我' }

      it { is_expected.to be false }
    end
  end

  describe '.patience_limit' do
    subject { described_class.patience_limit('Friendly') }

    it { is_expected.to eq(4) }
  end

  describe '.turn' do
    subject(:result) { described_class.turn(row) }

    context 'when the first offer meets the opening' do
      let(:row) { turn_row(epic_neutral, 'round' => '1', 'best_offer' => '', 'last_offer' => '', 'player_offer' => '62') }

      it 'is expected to sell at the offer' do
        expect(result).to include(outcome: :deal, action: 'sell', price: 62, counter: 60)
      end
    end

    context 'when the player accepts again after declining a deal' do
      let(:row) { turn_row(epic_neutral, 'best_offer' => '60', 'last_offer' => '60', 'player_offer' => '60') }

      it 'is expected to offer the deal again for one patience' do
        expect(result).to include(outcome: :deal, action: 'sell', price: 60, patience: 2)
      end
    end

    context 'when accepting again after declining a deal costs the last patience' do
      let(:row) do
        turn_row(epic_neutral, 'patience' => '1', 'best_offer' => '60', 'last_offer' => '60', 'player_offer' => '60')
      end

      it { is_expected.to include(outcome: :walkaway, action: 'refuse') }
    end

    context 'when the first deal costs no patience' do
      let(:row) { turn_row(epic_neutral, 'patience' => '1', 'player_offer' => '60') }

      it { is_expected.to include(outcome: :deal, patience: 1) }
    end

    context 'when a friend is offered more than the counter' do
      let(:row) do
        turn_row({ 'item_rarity' => 'Common', 'item_expected_price' => '10', 'relationship_status' => 'Friendly' },
                 'counter_price' => '10', 'best_offer' => '8', 'last_offer' => '8', 'player_offer' => '12')
      end

      it 'is expected to sell at the counter' do
        expect(result).to include(outcome: :deal, action: 'sell', price: 10)
      end
    end

    context 'when a raise earns a concession that stays above the offer' do
      let(:row) { turn_row(epic_neutral, 'player_offer' => '56') }

      it 'is expected to counter at the conceded price without costing patience' do
        expect(result).to include(outcome: :counter, action: 'negotiate', price: 57, counter: 57, patience: 3)
      end
    end

    context 'when the concession reaches the offer' do
      let(:row) { turn_row(epic_neutral, 'player_offer' => '58') }

      it 'is expected to sell at the offer after conceding' do
        expect(result).to include(outcome: :deal, price: 58, counter: 57)
      end
    end

    context 'when a raise is smaller than the progress step' do
      let(:row) { turn_row(epic_neutral, 'best_offer' => '56', 'last_offer' => '56', 'player_offer' => '57') }

      it 'is expected to hold the counter and cost one patience' do
        expect(result).to include(outcome: :counter, counter: 60, patience: 2)
      end
    end

    context 'when the player drops back below the best offer' do
      let(:row) { turn_row(epic_neutral, 'best_offer' => '56', 'last_offer' => '56', 'player_offer' => '50') }

      it 'is expected to hold the counter and cost one patience' do
        expect(result).to include(outcome: :counter, counter: 60, patience: 2)
      end
    end

    context 'when the offer is below half the floor' do
      let(:row) { turn_row(epic_neutral, 'player_offer' => '20') }

      it 'is expected to cost two patience' do
        expect(result).to include(outcome: :counter, counter: 60, patience: 1)
      end
    end

    context 'when a jump follows an insult' do
      let(:row) { turn_row(epic_neutral, 'best_offer' => '10', 'last_offer' => '10', 'player_offer' => '56') }

      it 'is expected to cap the concession at a quarter of the range' do
        expect(result).to include(outcome: :counter, counter: 57)
      end
    end

    context 'when a turn without progress costs the last patience' do
      let(:row) { turn_row(epic_neutral, 'patience' => '1', 'best_offer' => '56', 'last_offer' => '56', 'player_offer' => '56') }

      it 'is expected to walk away' do
        expect(result).to include(outcome: :walkaway, action: 'refuse', price: nil, patience: 0)
      end
    end

    context 'when the player haggles without a price in the first round' do
      let(:row) { turn_row(epic_neutral, 'round' => '1', 'best_offer' => '', 'last_offer' => '', 'intent' => 'haggle') }

      it 'is expected to repeat the counter for free' do
        expect(result).to include(outcome: :counter, action: 'negotiate', price: 60, patience: 3)
      end
    end

    context 'when the player haggles without a price after the first round' do
      let(:row) { turn_row(epic_neutral, 'intent' => 'haggle') }

      it 'is expected to cost one patience without conceding' do
        expect(result).to include(outcome: :counter, price: 60, patience: 2)
      end
    end

    context 'when a haggle costs the last patience' do
      let(:row) { turn_row(epic_neutral, 'patience' => '1', 'intent' => 'haggle') }

      it { is_expected.to include(outcome: :walkaway, action: 'refuse') }
    end

    context 'when the player chats' do
      let(:row) { turn_row(epic_neutral, 'intent' => 'chat') }

      it 'is expected to leave the negotiation unchanged' do
        expect(result).to include(outcome: :chat, action: 'talk', price: nil, counter: 60, patience: 3)
      end
    end

    context 'when the player threatens' do
      let(:row) { turn_row(epic_neutral, 'intent' => 'threat') }

      it { is_expected.to include(outcome: :walkaway, action: 'refuse', counter: 60, patience: 0) }
    end

    context 'when a Neutral merchant meets rudeness' do
      let(:row) { turn_row(epic_neutral, 'rude' => 'severe', 'player_offer' => '56') }

      it { is_expected.to include(outcome: :walkaway, action: 'refuse') }
    end

    context 'when a Neutral merchant meets mild rudeness' do
      let(:row) { turn_row(epic_neutral, 'rude' => 'mild', 'player_offer' => '56') }

      it { is_expected.to include(outcome: :counter, action: 'negotiate') }
    end

    context 'when a Hostile merchant meets mild rudeness' do
      let(:row) do
        turn_row({ 'item_rarity' => 'Common', 'item_expected_price' => '10', 'relationship_status' => 'Hostile' },
                 'counter_price' => '17', 'best_offer' => '13', 'last_offer' => '13', 'rude' => 'mild', 'player_offer' => '14')
      end

      it { is_expected.to include(outcome: :walkaway, action: 'refuse') }
    end

    context 'when an Allied merchant meets rudeness' do
      let(:row) do
        turn_row({ 'item_rarity' => 'Common', 'item_expected_price' => '14', 'relationship_status' => 'Allied' },
                 'counter_price' => '11', 'best_offer' => '8', 'last_offer' => '8', 'rude' => 'severe', 'player_offer' => '9')
      end

      it 'is expected to answer the offer as usual' do
        expect(result).to include(outcome: :counter, action: 'negotiate', counter: 10)
      end
    end
  end
end
