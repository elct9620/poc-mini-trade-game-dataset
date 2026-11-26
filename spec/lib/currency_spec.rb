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

  describe 'TRAIN' do
    it { expect(Currency::TRAIN & Currency::TEST).to be_empty }
  end
end
