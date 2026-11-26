# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/currency'

RSpec.describe Currency do
  describe '.pick' do
    let(:row) { { 'item_name' => '林語豎琴' } }

    it { expect(Currency::TRAIN).to include(described_class.pick(row, Currency::TRAIN)) }
    it { expect(Currency::TEST).to include(described_class.pick(row, Currency::TEST)) }

    it 'is expected to keep one item in one currency' do
      expect(described_class.pick(row, Currency::TRAIN)).to eq(described_class.pick(row.dup, Currency::TRAIN))
    end

    it 'is expected to move each copy to another currency' do
      picks = (0..2).map { |copy| described_class.pick(row, Currency::TRAIN, copy) }
      expect(picks.uniq.size).to eq(3)
    end
  end

  describe '.collision' do
    it { expect(described_class.collision({ 'item_name' => '銀鎖鏈' })).to eq('鎖鏈') }
  end

  describe '.collides?' do
    subject { described_class.collides?(row) }

    context 'when the line names the item' do
      let(:row) { { 'item_name' => '銀鎖鏈', 'input' => '這鎖鏈1214金幣就好。' } }

      it { is_expected.to be(true) }
    end

    context 'when only the previous turn names the item' do
      let(:row) { { 'item_name' => '銀鎖鏈', 'input' => '1214金幣。', 'previous_player' => '鎖鏈多少？' } }

      it { is_expected.to be(true) }
    end

    context 'when the line does not name the item' do
      let(:row) { { 'item_name' => '銀鎖鏈', 'input' => '1214金幣就好。' } }

      it { is_expected.to be(false) }
    end
  end

  describe 'TRAIN' do
    it { expect(Currency::TRAIN & Currency::TEST).to be_empty }
  end
end
