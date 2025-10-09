# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/validator/rarity_validator'

RSpec.describe Validator::RarityValidator do
  describe '#validate' do
    subject(:validation_result) { described_class.new.validate(row) }

    context 'when item_rarity is Common' do
      let(:row) { CSV::Row.new(['item_rarity'], ['Common']) }

      it { is_expected.to be true }
    end

    context 'when item_rarity is Rare' do
      let(:row) { CSV::Row.new(['item_rarity'], ['Rare']) }

      it { is_expected.to be true }
    end

    context 'when item_rarity is Epic' do
      let(:row) { CSV::Row.new(['item_rarity'], ['Epic']) }

      it { is_expected.to be true }
    end

    context 'when item_rarity is nil' do
      let(:row) { CSV::Row.new(['item_rarity'], [nil]) }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, 'Missing item_rarity column')
      end
    end

    context 'when item_rarity is empty string' do
      let(:row) { CSV::Row.new(['item_rarity'], ['']) }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, 'Missing item_rarity column')
      end
    end

    context 'when item_rarity is invalid' do
      let(:row) { CSV::Row.new(['item_rarity'], ['Legendary']) }

      it 'is expected to raise ValidationError with valid values' do
        expect { validation_result }.to raise_error(ValidationError, /Invalid rarity 'Legendary'/)
      end
    end
  end
end
