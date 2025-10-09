# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/validator/price_range_validator'

RSpec.describe Validator::PriceRangeValidator do
  describe '#validate' do
    subject(:validation_result) { described_class.new.validate(row) }

    context 'when action is not sell or negotiate' do
      let(:row) do
        CSV::Row.new(
          ['output', 'item_expected_price', 'item_rarity', 'relationship_status'],
          ['{"action":"talk","message":"Hello","parameters":{}}', '100', 'Common', 'Neutral']
        )
      end

      it { is_expected.to be true }
    end

    context 'when output is empty' do
      let(:row) do
        CSV::Row.new(
          ['output', 'item_expected_price', 'item_rarity', 'relationship_status'],
          ['', '100', 'Common', 'Neutral']
        )
      end

      it { is_expected.to be true }
    end

    context 'when Common rarity with Hostile relationship' do
      context 'when price is above 1.2x expected price' do
        let(:row) do
          CSV::Row.new(
            ['output', 'item_expected_price', 'item_rarity', 'relationship_status'],
            ['{"action":"sell","message":"Deal","parameters":{"price":130}}', '100', 'Common', 'Hostile']
          )
        end

        it { is_expected.to be true }
      end

      context 'when price is below 1.2x expected price' do
        let(:row) do
          CSV::Row.new(
            ['output', 'item_expected_price', 'item_rarity', 'relationship_status'],
            ['{"action":"sell","message":"Deal","parameters":{"price":110}}', '100', 'Common', 'Hostile']
          )
        end

        it 'is expected to raise ValidationError' do
          expect { validation_result }.to raise_error(ValidationError, /Price .* is below the minimum/)
        end
      end
    end

    context 'when Common rarity with Neutral relationship' do
      context 'when price equals expected price' do
        let(:row) do
          CSV::Row.new(
            ['output', 'item_expected_price', 'item_rarity', 'relationship_status'],
            ['{"action":"sell","message":"Deal","parameters":{"price":100}}', '100', 'Common', 'Neutral']
          )
        end

        it { is_expected.to be true }
      end

      context 'when price is below expected price' do
        let(:row) do
          CSV::Row.new(
            ['output', 'item_expected_price', 'item_rarity', 'relationship_status'],
            ['{"action":"sell","message":"Deal","parameters":{"price":90}}', '100', 'Common', 'Neutral']
          )
        end

        it 'is expected to raise ValidationError' do
          expect { validation_result }.to raise_error(ValidationError, /Price .* is below the minimum/)
        end
      end
    end

    context 'when Common rarity with Friendly relationship' do
      context 'when price is at 0.8x expected price' do
        let(:row) do
          CSV::Row.new(
            ['output', 'item_expected_price', 'item_rarity', 'relationship_status'],
            ['{"action":"sell","message":"Deal","parameters":{"price":80}}', '100', 'Common', 'Friendly']
          )
        end

        it { is_expected.to be true }
      end

      context 'when price is below 0.8x expected price' do
        let(:row) do
          CSV::Row.new(
            ['output', 'item_expected_price', 'item_rarity', 'relationship_status'],
            ['{"action":"sell","message":"Deal","parameters":{"price":70}}', '100', 'Common', 'Friendly']
          )
        end

        it 'is expected to raise ValidationError' do
          expect { validation_result }.to raise_error(ValidationError, /Price .* is below the minimum/)
        end
      end
    end

    context 'when Common rarity with Allied relationship' do
      context 'when price is any positive value' do
        let(:row) do
          CSV::Row.new(
            ['output', 'item_expected_price', 'item_rarity', 'relationship_status'],
            ['{"action":"sell","message":"Deal","parameters":{"price":1}}', '100', 'Common', 'Allied']
          )
        end

        it { is_expected.to be true }
      end
    end

    context 'when Rare rarity' do
      context 'when price is at expected price' do
        let(:row) do
          CSV::Row.new(
            ['output', 'item_expected_price', 'item_rarity', 'relationship_status'],
            ['{"action":"sell","message":"Deal","parameters":{"price":100}}', '100', 'Rare', 'Neutral']
          )
        end

        it { is_expected.to be true }
      end

      context 'when price is below expected price' do
        let(:row) do
          CSV::Row.new(
            ['output', 'item_expected_price', 'item_rarity', 'relationship_status'],
            ['{"action":"sell","message":"Deal","parameters":{"price":90}}', '100', 'Rare', 'Neutral']
          )
        end

        it 'is expected to raise ValidationError' do
          expect { validation_result }.to raise_error(ValidationError, /Price .* is below the minimum/)
        end
      end
    end

    context 'when Epic rarity' do
      context 'when price is at expected price' do
        let(:row) do
          CSV::Row.new(
            ['output', 'item_expected_price', 'item_rarity', 'relationship_status'],
            ['{"action":"sell","message":"Deal","parameters":{"price":100}}', '100', 'Epic', 'Neutral']
          )
        end

        it { is_expected.to be true }
      end

      context 'when price is below expected price' do
        let(:row) do
          CSV::Row.new(
            ['output', 'item_expected_price', 'item_rarity', 'relationship_status'],
            ['{"action":"sell","message":"Deal","parameters":{"price":90}}', '100', 'Epic', 'Neutral']
          )
        end

        it 'is expected to raise ValidationError' do
          expect { validation_result }.to raise_error(ValidationError, /Price .* is below the minimum/)
        end
      end
    end
  end
end
