# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/rows'
require_relative '../../lib/rebalancing'

RSpec.describe Rebalancing do
  describe '#execute' do
    subject(:pairs) { described_class.new(rows, ->(row) { row['attitude'] }).execute }

    let(:cells) { pairs.map { |row, _| row['attitude'] }.tally }
    let(:long) { 'x' * 20 }

    context 'when one cell dominates' do
      let(:rows) do
        Array.new(80) { |i| VALID_ROW.merge('id' => i.to_s, 'input' => long) } +
          %w[polite mild severe c4 c5 c6 c7].flat_map do |a|
            Array.new(10) { |i| VALID_ROW.merge('id' => "#{a}#{i}", 'attitude' => a) }
          end
      end

      it { expect(cells['plain']).to be <= 0.15 * pairs.size }
      it { expect(cells['polite']).to eq(10) }
    end

    context 'when a capped cell has rows with rare features' do
      let(:rows) do
        [VALID_ROW.merge('id' => 'short', 'input' => '算我')] +
          Array.new(40) { |i| VALID_ROW.merge('id' => i.to_s, 'input' => long) } +
          %w[polite mild severe].flat_map { |a| Array.new(20) { |i| VALID_ROW.merge('id' => "#{a}#{i}", 'attitude' => a) } }
      end

      it { expect(pairs.map { |row, _| row['id'] }).to include('short') }
    end

    context 'when a cell is under a quarter of the mean cell' do
      let(:rows) do
        Array.new(30) { |i| VALID_ROW.merge('id' => "p#{i}", 'attitude' => 'plain') } +
          Array.new(30) { |i| VALID_ROW.merge('id' => "o#{i}", 'attitude' => 'polite') } +
          [VALID_ROW.merge('id' => 'rare', 'attitude' => 'mild')]
      end

      it 'is expected to copy its rows, numbering each copy' do
        expect(pairs.select { |row, _| row['id'] == 'rare' }.map(&:last)).to eq([0, 1, 2])
      end
    end
  end
end
