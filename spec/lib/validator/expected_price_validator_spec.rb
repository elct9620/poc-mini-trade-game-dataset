# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/validator/expected_price_validator'

RSpec.describe Validator::ExpectedPriceValidator do
  describe '#validate' do
    subject(:validation_result) { described_class.new.validate(row) }

    context 'when item_expected_price is a valid positive number' do
      let(:row) { CSV::Row.new(['item_expected_price'], ['100']) }

      it { is_expected.to be true }
    end

    context 'when item_expected_price is a valid decimal number' do
      let(:row) { CSV::Row.new(['item_expected_price'], ['99.99']) }

      it { is_expected.to be true }
    end

    context 'when item_expected_price is nil' do
      let(:row) { CSV::Row.new(['item_expected_price'], [nil]) }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, 'Missing item_expected_price column')
      end
    end

    context 'when item_expected_price is empty string' do
      let(:row) { CSV::Row.new(['item_expected_price'], ['']) }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, 'Missing item_expected_price column')
      end
    end

    context 'when item_expected_price is zero' do
      let(:row) { CSV::Row.new(['item_expected_price'], ['0']) }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, 'Expected price must be greater than 0')
      end
    end

    context 'when item_expected_price is negative' do
      let(:row) { CSV::Row.new(['item_expected_price'], ['-10']) }

      it 'is expected to raise ValidationError' do
        expect { validation_result }.to raise_error(ValidationError, 'Expected price must be greater than 0')
      end
    end
  end
end
